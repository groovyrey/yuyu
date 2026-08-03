package com.ryu.vx.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Diamond
import androidx.compose.material.icons.filled.MonetizationOn
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.ryu.vx.data.model.HeroEntry
import com.ryu.vx.data.model.Skin
import com.ryu.vx.data.model.SkinToSkin
import com.ryu.vx.viewmodel.AppViewModel

private val CLASSES = listOf("Tank", "Fighter", "Assassin", "Mage", "Marksman", "Support")

private fun primaryClass(hero: HeroEntry): String =
    hero.heroInfo.role.trim().split(" ").first().ifBlank { "Unknown" }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HeroesScreen(
    vm: AppViewModel,
    onFavoriteChange: (HeroEntry, Skin, String, Boolean) -> Unit
) {
    var selectedHero by remember { mutableStateOf<HeroEntry?>(null) }
    var selectedClass by remember { mutableStateOf<String?>(null) }

    val heroes = vm.heroes.collectAsState().value
    val loading = vm.loading.collectAsState().value
    val error = vm.loadError.collectAsState().value

    LaunchedEffect(selectedHero) {
        if (selectedHero == null) vm.refreshInjectedStatus()
    }

    if (selectedHero != null) {
        HeroDetailScreen(
            hero = selectedHero!!,
            vm = vm,
            onFavoriteChange = onFavoriteChange,
            onBack = { selectedHero = null }
        )
        return
    }

    if (selectedClass != null) {
        val filtered = heroes.filter { primaryClass(it) == selectedClass }
        ClassHeroesScreen(
            className = selectedClass!!,
            heroes = filtered,
            onBack = { selectedClass = null },
            onHeroClick = { selectedHero = it }
        )
        return
    }

    Scaffold(topBar = { TopAppBar(title = { Text("Heroes") }) }) { padding ->
        when {
            loading -> Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            error != null -> Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Failed to load heroes", color = MaterialTheme.colorScheme.error)
                    Text(error, style = MaterialTheme.typography.bodySmall)
                }
            }
            else -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                item {
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(CLASSES) { cls ->
                            FilterChip(
                                selected = false,
                                onClick = { selectedClass = cls },
                                label = { Text(cls) }
                            )
                        }
                    }
                }
                items(heroes, key = { it.heroInfo.id }) { hero ->
                    HeroRow(
                        hero = hero,
                        onClick = { selectedHero = hero }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ClassHeroesScreen(
    className: String,
    heroes: List<HeroEntry>,
    onBack: () -> Unit,
    onHeroClick: (HeroEntry) -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("$className Heroes") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(heroes, key = { it.heroInfo.id }) { hero ->
                HeroRow(
                    hero = hero,
                    onClick = { onHeroClick(hero) }
                )
            }
        }
    }
}

@Composable
private fun HeroRow(hero: HeroEntry, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            AsyncImage(
                model = hero.heroInfo.portraitIcon,
                contentDescription = hero.heroInfo.name,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(48.dp)
                    .padding(4.dp)
            )
            Column(Modifier.weight(1f).padding(horizontal = 8.dp)) {
                Text(
                    text = hero.heroInfo.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = hero.heroInfo.role,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary
                )
            }
            Text(
                text = ">",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HeroDetailScreen(
    hero: HeroEntry,
    vm: AppViewModel,
    onFavoriteChange: (HeroEntry, Skin, String, Boolean) -> Unit,
    onBack: () -> Unit
) {
    val snackbarHostState = remember { SnackbarHostState() }
    val operation = vm.operation.collectAsState().value
    var lastShown by remember { mutableStateOf("") }
    LaunchedEffect(operation.running, operation.message) {
        if (operation.running) return@LaunchedEffect
        val msg = operation.message
        if (msg.isNotBlank() && msg != lastShown && msg.startsWith("Injected")) {
            lastShown = msg
            snackbarHostState.showSnackbar(msg)
        }
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(hero.heroInfo.name) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
        ) {
            HeroHeader(hero)

            Text(
                text = "About",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )
            HeroDescription(hero)

            Text(
                text = "Skins",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(hero.skins, key = { it.id }) { skin ->
                    val sc = findSkinUrl(hero, skin)
                    SkinCard(
                        hero = hero,
                        skin = skin,
                        vm = vm,
                        onFavoriteChange = onFavoriteChange,
                        downloadUrl = sc
                    )
                }
            }

            val s2s = hero.skinToSkin
            if (s2s.isNotEmpty()) {
                Text(
                    text = "Skin to Skin",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                )
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    items(s2s.size) { groupIndex ->
                        val group = s2s[groupIndex]
                        val from = skinForId(hero, group.firstOrNull()?.skinInfo)
                        val to = skinForId(hero, group.lastOrNull()?.skinInfo)
                        SkinToSkinCard(
                            hero = hero,
                            from = from,
                            to = to,
                            sc = group.lastOrNull()?.sc.orEmpty(),
                            vm = vm
                        )
                    }
                }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun HeroHeader(hero: HeroEntry) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(bottomStart = 24.dp, bottomEnd = 24.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            AsyncImage(
                model = hero.heroInfo.portraitIcon,
                contentDescription = hero.heroInfo.name,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(96.dp)
                    .clip(RoundedCornerShape(16.dp))
            )
            Column(Modifier.weight(1f).padding(start = 16.dp)) {
                Text(hero.heroInfo.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                Text(
                    "${hero.heroInfo.role} • ${hero.heroInfo.lane}",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.primary
                )
                if (hero.heroInfo.price.isNotBlank()) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        val parts = hero.heroInfo.price.trim().split(" ")
                        val bp = parts.getOrNull(0).orEmpty()
                        val diamonds = parts.getOrNull(1).orEmpty()
                        if (bp.isNotBlank()) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                Icon(
                                    Icons.Filled.MonetizationOn,
                                    contentDescription = "Battle Points",
                                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                                )
                                Text(
                                    bp,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                                )
                            }
                        }
                        if (diamonds.isNotBlank()) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                Icon(
                                    Icons.Filled.Diamond,
                                    contentDescription = "Diamonds",
                                    tint = MaterialTheme.colorScheme.primary
                                )
                                Text(
                                    diamonds,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HeroDescription(hero: HeroEntry) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(Modifier.padding(16.dp)) {
            if (hero.heroInfo.quote.isNotBlank()) {
                Text(
                    text = hero.heroInfo.quote,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Medium
                )
                Spacer(Modifier.height(8.dp))
            }
            if (hero.heroInfo.specialty.isNotBlank()) {
                InfoRow("Specialty", hero.heroInfo.specialty)
            }
            if (hero.heroInfo.releaseDate.isNotBlank()) {
                InfoRow("Released", hero.heroInfo.releaseDate)
            }
            if (hero.heroInfo.price.isNotBlank()) {
                InfoRow("Price", hero.heroInfo.price)
            }
            val stats = hero.heroInfo.baseStats
            if (stats.hp.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text("Base Stats", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                InfoRow("HP", stats.hp)
                InfoRow("Mana", stats.mana)
                InfoRow("Physical Attack", stats.physicalAttack)
                InfoRow("Physical Defense", stats.physicalDefense)
                InfoRow("Move Speed", stats.movementSpeed)
            }
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            modifier = Modifier.weight(1f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.End
        )
    }
}

private fun skinForId(hero: HeroEntry, id: Int?): Skin? =
    if (id == null) null else hero.skins.firstOrNull { it.id == id }

@Composable
private fun SkinToSkinCard(
    hero: HeroEntry,
    from: Skin?,
    to: Skin?,
    sc: String,
    vm: AppViewModel
) {
    val operation = vm.operation.collectAsState().value
    val label = "${from?.name ?: "?"} → ${to?.name ?: "?"}"
    val injecting = operation.running && operation.message.contains("→")
    Card(
        modifier = Modifier.width(180.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column {
            Box(Modifier.fillMaxWidth().height(90.dp)) {
                AsyncImage(
                    model = to?.image,
                    contentDescription = to?.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            }
            Column(Modifier.padding(10.dp)) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                    minLines = 2
                )
                Spacer(Modifier.height(6.dp))
                if (injecting) {
                    LinearProgressIndicator(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(4.dp),
                        trackColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                } else {
                    Button(
                        onClick = {
                            from?.let { f ->
                                to?.let { t ->
                                    vm.injectSkinToSkin(hero, f.name, t.name, sc)
                                }
                            }
                        },
                        enabled = sc.isNotBlank() && !operation.running && from != null && to != null,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Transform")
                    }
                }
            }
        }
    }
}

private fun findSkinUrl(hero: HeroEntry, skin: Skin): String {
    hero.defaultSkins.firstOrNull { it.skinInfo == skin.id }?.let { return it.sc }
    hero.skinToSkin.flatten().firstOrNull { it.skinInfo == skin.id }?.let { return it.sc }
    hero.skinToSkin.firstOrNull()?.firstOrNull()?.let { return it.sc }
    return ""
}

@Composable
private fun SkinCard(
    hero: HeroEntry,
    skin: Skin,
    vm: AppViewModel,
    onFavoriteChange: (HeroEntry, Skin, String, Boolean) -> Unit,
    downloadUrl: String
) {
    val isFavorite = vm.favorites.collectAsState().value.any { it.heroId == hero.heroInfo.id && it.skinName == skin.name }
    val injected = vm.injected.collectAsState().value.contains("${hero.heroInfo.id}:${skin.name}")
    Card(
        modifier = Modifier.width(140.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.background)
    ) {
        Column {
            Box(Modifier.fillMaxWidth().height(100.dp)) {
                if (skin.image.isNotBlank()) {
                    AsyncImage(
                        model = skin.image,
                        contentDescription = skin.name,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize()
                    )
                }
                IconButton(
                    onClick = { onFavoriteChange(hero, skin, downloadUrl, isFavorite) },
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .size(36.dp)
                ) {
                    Icon(
                        imageVector = if (isFavorite) Icons.Filled.Star else Icons.Outlined.StarBorder,
                        contentDescription = if (isFavorite) "Remove from favorites" else "Add to favorites",
                        tint = if (isFavorite) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        }
                    )
                }
            }
            Column(Modifier.padding(8.dp)) {
                Text(
                    text = skin.name,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                    minLines = 2
                )
                Text(
                    text = if (downloadUrl.isNotBlank()) skin.type else "Not available",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary,
                    textAlign = TextAlign.Center
                )
                Spacer(Modifier.height(8.dp))
                val operation = vm.operation.collectAsState().value
                val injecting = operation.running && operation.message.contains(skin.name)
                if (injecting) {
                    LinearProgressIndicator(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(4.dp),
                        trackColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                } else {
                    Button(
                        onClick = { vm.injectSkin(hero, skin.name, skin.image, downloadUrl) },
                        enabled = downloadUrl.isNotBlank() && !operation.running && !injected,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(if (injected) "Injected ✓" else "Inject")
                    }
                }
            }
        }
    }
}
