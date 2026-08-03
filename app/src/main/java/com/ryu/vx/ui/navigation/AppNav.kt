package com.ryu.vx.ui.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoFixHigh
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import com.ryu.vx.ui.screens.FavoritesScreen
import com.ryu.vx.ui.screens.HeroesScreen
import com.ryu.vx.ui.screens.RestoreScreen
import com.ryu.vx.ui.screens.SettingsScreen
import com.ryu.vx.viewmodel.AppViewModel

private enum class Tab(val label: String, val icon: ImageVector) {
    Heroes("Heroes", Icons.Filled.Person),
    Favorites("Favorites", Icons.Filled.Favorite),
    Restore("Restore", Icons.Filled.AutoFixHigh),
    Settings("Settings", Icons.Filled.Settings)
}

@Composable
fun AppNavigation(vm: AppViewModel) {
    var selected by rememberSaveable { mutableIntStateOf(0) }
    val tabs = Tab.entries

    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEachIndexed { index, tab ->
                    NavigationBarItem(
                        selected = selected == index,
                        onClick = { selected = index },
                        icon = { Icon(tab.icon, contentDescription = tab.label) },
                        label = { Text(tab.label) }
                    )
                }
            }
        }
    ) { innerPadding ->
        Box(Modifier.fillMaxSize().padding(innerPadding)) {
            when (tabs[selected]) {
                Tab.Heroes -> HeroesScreen(vm) { hero, skin, sc, isFavorite ->
                    if (isFavorite) {
                        vm.removeFavorite(hero.heroInfo.id, skin.name)
                    } else {
                        vm.addFavorite(hero, skin.name, skin.image, sc)
                    }
                }
                Tab.Favorites -> FavoritesScreen(vm)
                Tab.Restore -> RestoreScreen(vm)
                Tab.Settings -> SettingsScreen(vm)
            }
        }
    }
}
