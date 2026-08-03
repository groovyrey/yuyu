package com.ryu.vx.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val DarkColors = darkColorScheme(
    primary = Color(0xFF2DD4BF),
    onPrimary = Color(0xFF00332C),
    secondary = Color(0xFF14B8A6),
    tertiary = Color(0xFFF59E0B),
    background = Color(0xFF0B1312),
    surface = Color(0xFF152220),
    surfaceVariant = Color(0xFF1E2E2B),
    onBackground = Color(0xFFE8F3F0),
    onSurface = Color(0xFFE8F3F0)
)

private val LightColors = lightColorScheme(
    primary = Color(0xFF0D9488),
    onPrimary = Color.White,
    secondary = Color(0xFF2DD4BF),
    tertiary = Color(0xFFD97706),
    background = Color(0xFFF5FBF9),
    surface = Color.White,
    surfaceVariant = Color(0xFFE0F2EF),
    onBackground = Color(0xFF0B1312),
    onSurface = Color(0xFF0B1312)
)

@Composable
fun RyumotoVXTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content
    )
}
