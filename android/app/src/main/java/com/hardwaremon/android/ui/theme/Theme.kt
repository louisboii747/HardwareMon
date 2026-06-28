package com.hardwaremon.android.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val HardwareMonDarkColors = darkColorScheme(
    primary = ElectricBlue,
    onPrimary = Ink,
    secondary = Cyan,
    tertiary = Violet,
    background = Ink,
    onBackground = TextPrimary,
    surface = DeepNavy,
    onSurface = TextPrimary,
    surfaceVariant = CardNavy,
    onSurfaceVariant = TextSecondary,
    error = Danger,
    onError = Color.White,
    outline = Color(0xFF2A3A51),
)

@Composable
fun HardwareMonTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = HardwareMonDarkColors,
        typography = HardwareMonTypography,
        content = content,
    )
}
