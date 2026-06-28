package com.hardwaremon.companion.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import com.hardwaremon.companion.ui.theme.DeepNavy
import com.hardwaremon.companion.ui.theme.ElectricBlue
import com.hardwaremon.companion.ui.theme.Ink
import com.hardwaremon.companion.ui.theme.Violet

@Composable
fun AppBackground(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(DeepNavy, Ink))),
    ) {
        Canvas(Modifier.fillMaxSize()) {
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(ElectricBlue.copy(alpha = 0.13f), ElectricBlue.copy(alpha = 0f)),
                    center = Offset(size.width * 0.9f, size.height * 0.05f),
                    radius = size.minDimension * 0.7f,
                ),
                radius = size.minDimension * 0.7f,
                center = Offset(size.width * 0.9f, size.height * 0.05f),
            )
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(Violet.copy(alpha = 0.09f), Violet.copy(alpha = 0f)),
                    center = Offset(0f, size.height * 0.75f),
                    radius = size.minDimension * 0.55f,
                ),
                radius = size.minDimension * 0.55f,
                center = Offset(0f, size.height * 0.75f),
            )
        }
        content()
    }
}
