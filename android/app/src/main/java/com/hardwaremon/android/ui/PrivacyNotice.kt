package com.hardwaremon.android.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

object PrivacyNoticeCopy {
    const val summary =
        "Privacy-first: monitoring, diagnostics, and benchmarks stay on this device. " +
            "HardwareMon does not currently upload telemetry or benchmark results."
}

@Composable
fun PrivacyNoticeHost(content: @Composable () -> Unit) {
    val snackbarHostState = remember { SnackbarHostState() }
    var showDetails by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        val result = snackbarHostState.showSnackbar(
            message = PrivacyNoticeCopy.summary,
            actionLabel = "Details",
            withDismissAction = true,
            duration = SnackbarDuration.Long,
        )
        if (result == SnackbarResult.ActionPerformed) {
            showDetails = true
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        content()
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = 16.dp, vertical = 24.dp),
        )
    }

    if (showDetails) {
        PrivacySummaryDialog(onDismiss = { showDetails = false })
    }
}

@Composable
private fun PrivacySummaryDialog(onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Privacy at a glance") },
        text = {
            Column {
                Text("HardwareMon processes CPU, GPU, memory, storage, network, process, telemetry, diagnostic, and benchmark information locally.")
                Spacer(modifier = Modifier.height(12.dp))
                Text("Settings, enabled history, benchmark results, and diagnostics you generate remain on this device unless you remove them.")
                Spacer(modifier = Modifier.height(12.dp))
                Text("Internet access may be used for update checks and downloads you request. Benchmark results are not currently uploaded.")
                Spacer(modifier = Modifier.height(12.dp))
                Text("Any future anonymous benchmark sharing will be optional, require explicit consent, and is intended to exclude usernames, files, applications, serial numbers, MAC addresses, and IP addresses.")
                Spacer(modifier = Modifier.height(12.dp))
                Text("HardwareMon is open source, allowing its data handling to be reviewed publicly.")
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Got it")
            }
        },
    )
}
