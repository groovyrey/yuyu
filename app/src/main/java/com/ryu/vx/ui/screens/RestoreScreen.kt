package com.ryu.vx.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.AutoFixHigh
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CloudDownload
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.SystemUpdateAlt
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.ryu.vx.data.model.Favorite
import com.ryu.vx.engine.GameTarget
import com.ryu.vx.shizuku.ShizukuManager
import com.ryu.vx.viewmodel.AppViewModel
import com.ryu.vx.viewmodel.OperationState

/**
 * "Restore" tab — a professional injector dashboard.
 *
 * Shows a readiness summary (game, storage, Shizuku), the main inject /
 * restore actions with live progress, and the favorites queue.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RestoreScreen(vm: AppViewModel) {
    val context = LocalContext.current
    val favorites = vm.favorites.collectAsState().value
    val operation = vm.operation.collectAsState().value
    val game = remember { vm.findGame() }
    val shizukuState = ShizukuManager.state.collectAsState().value
    val storageGranted = remember { checkStorage(context) }

    Scaffold(topBar = { TopAppBar(title = { Text("Injector") }) }) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item { ReadinessCard(game, shizukuState, storageGranted) }

            item {
                ActionCard(
                    title = "Inject All Favorites",
                    subtitle = "Download and apply every favorited skin into Mobile Legends.",
                    icon = Icons.Filled.SystemUpdateAlt,
                    buttonLabel = "Inject Now",
                    enabled = favorites.isNotEmpty() && !operation.running && isReady(game, shizukuState, storageGranted),
                    onClick = { vm.injectAllFavorites() }
                )
            }

            item {
                ActionCard(
                    title = "Advanced Restore",
                    subtitle = "Offline recovery — clears repair markers and re-applies cached skins.",
                    icon = Icons.Filled.Sync,
                    buttonLabel = "Restore All",
                    enabled = favorites.isNotEmpty() && !operation.running && isReady(game, shizukuState, storageGranted),
                    onClick = { vm.advancedRestoreAllFavorites() }
                )
            }

            if (operation.running || operation.message.isNotBlank()) {
                item { OperationPanel(operation) }
            }

            item {
                FavoritesHeader(favorites.size)
            }
            items(favorites, key = { "${it.heroId}:${it.skinName}" }) { favorite ->
                FavoriteListItem(favorite)
            }
        }
    }
}

private fun isReady(
    game: GameTarget?,
    shizuku: ShizukuManager.State,
    storageGranted: Boolean
): Boolean {
    if (game == null || !storageGranted) return false
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        shizuku == ShizukuManager.State.Bound
    } else {
        true
    }
}

@Composable
private fun ReadinessCard(
    game: GameTarget?,
    shizuku: ShizukuManager.State,
    storageGranted: Boolean
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(Modifier.padding(16.dp)) {
            Text(
                "Readiness",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(12.dp))

            ReadyRow(
                icon = Icons.Filled.AutoFixHigh,
                ok = game != null,
                label = if (game != null) "Game: ${game.packageName}" else "Game: not detected",
                hint = if (game != null) game.assetsDir.absolutePath else "Install Mobile Legends"
            )
            ReadyRow(
                icon = Icons.Filled.Storage,
                ok = storageGranted,
                label = if (storageGranted) "Storage: granted" else "Storage: required",
                hint = if (storageGranted) "Write access enabled" else "Enable in Settings"
            )
            ReadyRow(
                icon = Icons.Filled.CloudDownload,
                ok = shizuku == ShizukuManager.State.Bound || Build.VERSION.SDK_INT < Build.VERSION_CODES.R,
                label = shizukuLabel(shizuku),
                hint = shizukuHint(shizuku)
            )
        }
    }
}

private fun checkStorage(context: android.content.Context): Boolean =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        Environment.isExternalStorageManager()
    } else {
        context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
            PackageManager.PERMISSION_GRANTED
    }

@Composable
private fun ReadyRow(
    icon: ImageVector,
    ok: Boolean,
    label: String,
    hint: String
) {
    val tint = if (ok) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            imageVector = if (ok) Icons.Filled.CheckCircle else Icons.Filled.ErrorOutline,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(18.dp)
        )
        Column(Modifier.weight(1f)) {
            Text(label, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
            if (hint.isNotBlank()) {
                Text(
                    hint,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
            }
        }
    }
}

private fun shizukuLabel(state: ShizukuManager.State): String = when (state) {
    ShizukuManager.State.Bound -> "Shizuku: connected"
    ShizukuManager.State.Idle -> "Shizuku: not connected"
    ShizukuManager.State.NoPermission -> "Shizuku: no permission"
    ShizukuManager.State.Unavailable -> "Shizuku: unavailable"
}

private fun shizukuHint(state: ShizukuManager.State): String = when (state) {
    ShizukuManager.State.Bound -> "Elevated file access active"
    ShizukuManager.State.Idle -> "Tap Connect in Settings"
    ShizukuManager.State.NoPermission -> "Grant permission in Settings"
    ShizukuManager.State.Unavailable -> "Install and start Shizuku"
}

@Composable
private fun ActionCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    buttonLabel: String,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(16.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(46.dp)
                    .background(
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                        shape = RoundedCornerShape(12.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
            }
        }
        HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.surfaceVariant)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.End
        ) {
            Button(
                onClick = onClick,
                enabled = enabled,
                contentPadding = PaddingValues(horizontal = 20.dp, vertical = 10.dp)
            ) {
                Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(8.dp))
                Text(buttonLabel)
            }
        }
    }
}

@Composable
private fun OperationPanel(operation: OperationState) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.08f)),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (operation.running) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Spacer(Modifier.width(10.dp))
                }
                Text(
                    operation.message,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onBackground
                )
            }
            if (operation.total > 0) {
                Spacer(Modifier.height(10.dp))
                LinearProgressIndicator(
                    progress = { operation.progress / 100f },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp),
                    trackColor = MaterialTheme.colorScheme.surfaceVariant
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    "${operation.done} / ${operation.total}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                    modifier = Modifier.align(Alignment.End)
                )
            }
        }
    }
}

@Composable
private fun FavoritesHeader(count: Int) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            "Favorite Skins",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        Spacer(Modifier.weight(1f))
        if (count > 0) {
            Text(
                "$count selected",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
    if (count == 0) {
        Spacer(Modifier.height(8.dp))
        Text(
            "No favorites yet. Star skins in the Heroes tab to inject them here.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
        )
    }
}

@Composable
private fun FavoriteListItem(favorite: Favorite) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(
                        color = MaterialTheme.colorScheme.primary,
                        shape = RoundedCornerShape(4.dp)
                    )
            )
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(favorite.skinName, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyMedium)
                Text(
                    favorite.heroName,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
            }
            Icon(
                Icons.Filled.CloudDownload,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                modifier = Modifier.size(16.dp)
            )
        }
    }
}
