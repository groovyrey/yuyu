package com.ryu.vx.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.ryu.vx.data.model.Favorite
import com.ryu.vx.data.model.HeroEntry
import com.ryu.vx.data.network.LuminaApi
import com.ryu.vx.data.store.FavoritesStore
import com.ryu.vx.data.store.HistoryStore
import com.ryu.vx.engine.DirectStrategy
import com.ryu.vx.engine.ExtractionStrategy
import com.ryu.vx.engine.GameTarget
import com.ryu.vx.engine.InjectEngine
import com.ryu.vx.engine.ShizukuStrategy
import com.ryu.vx.shizuku.ShizukuManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

data class OperationState(
    val running: Boolean = false,
    val message: String = "",
    val progress: Int = 0,
    val done: Int = 0,
    val total: Int = 0
)

class AppViewModel(application: Application) : AndroidViewModel(application) {

    private val favoritesStore = FavoritesStore(application)
    private val historyStore = HistoryStore(application)

    private val _heroes = MutableStateFlow<List<HeroEntry>>(emptyList())
    val heroes: StateFlow<List<HeroEntry>> = _heroes.asStateFlow()

    private val _loading = MutableStateFlow(true)
    val loading: StateFlow<Boolean> = _loading.asStateFlow()

    private val _loadError = MutableStateFlow<String?>(null)
    val loadError: StateFlow<String?> = _loadError.asStateFlow()

    private val _operation = MutableStateFlow(OperationState())
    val operation: StateFlow<OperationState> = _operation.asStateFlow()

    /** Keys ("heroId:skinName") of skins currently present in the game files. */
    private val _injected = MutableStateFlow<Set<String>>(emptySet())
    val injected: StateFlow<Set<String>> = _injected.asStateFlow()

    val favorites = favoritesStore.favorites.stateIn(
        viewModelScope, SharingStarted.Eagerly, emptyList()
    )

    val history = historyStore.history.stateIn(
        viewModelScope, SharingStarted.Eagerly, emptyList()
    )

    @Volatile
    private var engine: InjectEngine? = null
    private var engineUsesShizuku = false

    private fun injectEngine(): InjectEngine {
        val useShizuku = ShizukuManager.service != null
        val cached = engine
        if (cached != null && engineUsesShizuku == useShizuku) return cached
        val created = InjectEngine(
            context = getApplication(),
            favoritesStore = favoritesStore,
            historyStore = historyStore,
            strategy = if (useShizuku) {
                ShizukuStrategy { ShizukuManager.awaitService() }
            } else {
                DirectStrategy()
            }
        )
        engine = created
        engineUsesShizuku = useShizuku
        return created
    }

    fun initShizuku() {
        ShizukuManager.init(getApplication())
    }

    fun requestShizuku() {
        ShizukuManager.requestPermission(getApplication())
    }

    fun loadHeroes() {
        viewModelScope.launch {
            _loading.value = true
            _loadError.value = null
            runCatching { LuminaApi.fetchHeroes() }
                .onSuccess { _heroes.value = it }
                .onFailure { _loadError.value = it.message }
            _loading.value = false
        }
    }

    fun findGame(): GameTarget? = injectEngine().findGame()

    /**
     * Recomputes which skins recorded in the injected manifest are still
     * actually applied to the game files. Bounded by a timeout so it never
     * hangs the UI while a Shizuku service is still connecting.
     */
    fun refreshInjectedStatus() {
        viewModelScope.launch {
            val result = withTimeoutOrNull(30_000) {
                injectEngine().checkAllInjected()
            }
            if (result != null) _injected.value = result
        }
    }

    fun addFavorite(hero: HeroEntry, skinName: String, image: String, sc: String) {
        viewModelScope.launch {
            favoritesStore.add(
                Favorite(
                    heroName = hero.heroInfo.name,
                    heroId = hero.heroInfo.id,
                    skinName = skinName,
                    skinImage = image,
                    skinSc = sc
                )
            )
        }
    }

    fun removeFavorite(heroId: Int, skinName: String) {
        viewModelScope.launch {
            favoritesStore.remove(heroId, skinName)
        }
    }

    /** Injects a single skin directly from the heroes page. */
    fun injectSkin(hero: HeroEntry, skinName: String, skinImage: String, sc: String) {
        viewModelScope.launch {
            _operation.value = OperationState(running = true, message = "Injecting $skinName...", total = 1)
            val result = injectEngine().injectFavorite(
                Favorite(
                    heroName = hero.heroInfo.name,
                    heroId = hero.heroInfo.id,
                    skinName = skinName,
                    skinImage = skinImage,
                    skinSc = sc
                )
            )
            result.fold(
                onSuccess = {
                    _injected.value = _injected.value + "${hero.heroInfo.id}:$skinName"
                    _operation.value = OperationState(
                        running = false,
                        message = "Injected: $skinName",
                        done = 1,
                        total = 1
                    )
                },
                onFailure = { e ->
                    _operation.value = OperationState(running = false, message = "Failed: ${e.message}")
                }
            )
        }
    }

    /** Injects a skin-to-skin mod: transforms owned [fromSkin] into [toSkin]. */
    fun injectSkinToSkin(hero: HeroEntry, fromSkin: String, toSkin: String, sc: String) {
        val label = "$fromSkin → $toSkin"
        viewModelScope.launch {
            _operation.value = OperationState(running = true, message = "Injecting $label...", total = 1)
            val result = injectEngine().injectFavorite(
                Favorite(
                    heroName = hero.heroInfo.name,
                    heroId = hero.heroInfo.id,
                    skinName = label,
                    skinImage = "",
                    skinSc = sc
                )
            )
            result.fold(
                onSuccess = {
                    _injected.value = _injected.value + "${hero.heroInfo.id}:$label"
                    _operation.value = OperationState(
                        running = false,
                        message = "Injected: $label",
                        done = 1,
                        total = 1
                    )
                },
                onFailure = { e ->
                    _operation.value = OperationState(running = false, message = "Failed: ${e.message}")
                }
            )
        }
    }

    /**
     * Inject all favorites.
     */
    fun injectAllFavorites() {
        viewModelScope.launch {
            val list = favorites.value
            if (list.isEmpty()) return@launch
            _operation.value = OperationState(running = true, message = "Injecting favorites...", total = list.size)
            val result = injectEngine().injectAllFavorites(list) { done, msg ->
                _operation.value = _operation.value.copy(
                    done = done, message = msg, progress = if (list.size > 0) (done * 100) / list.size else 0
                )
            }
            result.fold(
                onSuccess = { (done, failed, detail) ->
                    val suffix = if (detail.isNotEmpty()) "\n${detail.take(200)}" else ""
                    _operation.value = OperationState(running = false, message = "Inject completed: $done ok, $failed failed$suffix", done = done, total = list.size)
                },
                onFailure = { e ->
                    _operation.value = OperationState(running = false, message = "Failed: ${e.message}")
                }
            )
        }
    }

    /**
     * THE COMBINED FEATURE: inject every favorited skin using the advanced
     * restore algorithm (offline, repair-triggering) — run from its own tab.
     */
    fun advancedRestoreAllFavorites() {
        viewModelScope.launch {
            val list = favorites.value
            if (list.isEmpty()) return@launch
            _operation.value = OperationState(running = true, message = "Advanced restore running...", total = list.size)
            val result = injectEngine().advancedRestoreAll(list) { done, msg ->
                _operation.value = _operation.value.copy(
                    done = done, message = msg, progress = if (list.size > 0) (done * 100) / list.size else 0
                )
            }
            result.fold(
                onSuccess = { (done, failed) ->
                    _operation.value = OperationState(running = false, message = "Advanced restore completed: $done ok, $failed failed", done = done, total = list.size)
                },
                onFailure = { e ->
                    _operation.value = OperationState(running = false, message = "Failed: ${e.message}")
                }
            )
        }
    }
}
