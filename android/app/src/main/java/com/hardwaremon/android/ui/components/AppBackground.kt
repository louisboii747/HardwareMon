package com.hardwaremon.android.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import com.hardwaremon.android.ui.theme.DeepNavy
import com.hardwaremon.android.ui.theme.ElectricBlue
import com.hardwaremon.android.ui.theme.Ink
import com.hardwaremon.android.ui.theme.Violet

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
                    colors = listOf(ElectricBlue.copy(alpha = 0.14f), ElectricBlue.copy(alpha = 0f)),
                    center = Offset(size.width * 0.95f, size.height * 0.02f),
                    radius = size.minDimension * 0.75f,
                ),
                radius = size.minDimension * 0.75f,
                center = Offset(size.width * 0.95f, size.height * 0.02f),
            )
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(Violet.copy(alpha = 0.08f), Violet.copy(alpha = 0f)),
                    center = Offset(0f, size.height * 0.72f),
                    radius = size.minDimension * 0.62f,
                ),
                radius = size.minDimension * 0.62f,
                center = Offset(0f, size.height * 0.72f),
            )
        }
        content()
    }
}
