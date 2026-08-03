package com.ryu.vx.ui.screens

import android.Manifest
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Android
import androidx.compose.material.icons.filled.Face
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.ryu.vx.shizuku.ShizukuManager
import com.ryu.vx.viewmodel.AppViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: AppViewModel) {
    val context = LocalContext.current
    var refreshKey by remember { mutableStateOf(0) }
    val shizukuState = ShizukuManager.state.value
    val game = remember(context, refreshKey) { vm.findGame() }

    Scaffold(topBar = { TopAppBar(title = { Text("Settings") }) }) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            SettingCard(
                icon = Icons.Filled.Storage,
                title = "Storage Access",
                body = "Ryumoto VX requires storage permissions to modify game files and apply skins on your device.",
                action = {
                    val contextForLaunch = context
                    val granted = remember(refreshKey) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            Environment.isExternalStorageManager()
                        } else {
                            contextForLaunch.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
                                android.content.pm.PackageManager.PERMISSION_GRANTED
                        }
                    }
                    val grant = rememberLauncherForActivityResult(
                        ActivityResultContracts.RequestPermission()
                    ) { refreshKey++ }
                    Button(onClick = {
                        when {
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                                val intent =
                                    android.content.Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                                runCatching {
                                    contextForLaunch.startActivity(
                                        intent.setData(Uri.parse("package:${contextForLaunch.packageName}"))
                                    )
                                }.onFailure {
                                    // Some OEMs don't resolve the package-specific
                                    // action; fall back to the generic settings screen.
                                    runCatching {
                                        contextForLaunch.startActivity(
                                            android.content.Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                                        )
                                    }
                                }
                            }
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                                grant.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                            }
                        }
                        refreshKey++
                    }) { Text(if (granted) "Storage Access Granted ✓" else "Grant Storage Access") }
                }
            )

            SettingCard(
                icon = Icons.Filled.Android,
                title = "System Access (Shizuku)",
                body = shizukuStateText(shizukuState),
                action = {
                    Button(onClick = {
                        when (shizukuState) {
                            ShizukuManager.State.NoPermission -> vm.requestShizuku()
                            ShizukuManager.State.Unavailable -> {}
                            else -> ShizukuManager.bind(context)
                        }
                        refreshKey++
                    }) { Text(buttonText(shizukuState)) }
                }
            )

            SettingCard(
                icon = Icons.Filled.Android,
                title = "Game Detection",
                body = if (game != null) {
                    "Detected: ${game.packageName}\nAssets: ${game.assetsDir.absolutePath}"
                } else {
                    "Mobile Legends not detected. Install it and re-open this screen."
                },
                action = {
                    Button(onClick = { refreshKey++ }) { Text("Re-check") }
                }
            )

            SettingCard(
                icon = Icons.Filled.Face,
                title = "Developer",
                body = "Yuyu is developed and maintained by Dev Sunrey.",
                action = {}
            )
        }
    }
}

private fun shizukuStateText(state: ShizukuManager.State): String = when (state) {
    ShizukuManager.State.Unavailable -> "Shizuku is not running. Install Shizuku and grant permission to enable elevated access for Android 11+."
    ShizukuManager.State.NoPermission -> "Shizuku is running but permission was not granted yet."
    ShizukuManager.State.Idle -> "Shizuku permission granted. Tap to bind the service."
    ShizukuManager.State.Bound -> "Shizuku service bound — elevated file operations enabled."
}

private fun buttonText(state: ShizukuManager.State): String = when (state) {
    ShizukuManager.State.NoPermission -> "Grant Shizuku Permission"
    ShizukuManager.State.Unavailable -> "Unavailable"
    ShizukuManager.State.Idle -> "Connect"
    ShizukuManager.State.Bound -> "Connected"
}

@Composable
private fun SettingCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    body: String,
    action: @Composable () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(4.dp))
                Text(body, style = MaterialTheme.typography.bodySmall)
                Spacer(Modifier.height(8.dp))
                action()
            }
        }
    }
}
