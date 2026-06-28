package com.hardwaremon.companion.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hardwaremon.companion.ui.components.AppBackground
import com.hardwaremon.companion.ui.theme.CardNavy
import com.hardwaremon.companion.ui.theme.Danger
import com.hardwaremon.companion.ui.theme.ElectricBlue
import com.hardwaremon.companion.ui.theme.Success
import com.hardwaremon.companion.ui.theme.TextSecondary
import com.hardwaremon.companion.viewmodel.ConnectionStatus
import com.hardwaremon.companion.viewmodel.MainUiState

@Composable
fun ConnectScreen(
    state: MainUiState,
    onUrlChanged: (String) -> Unit,
    onConnect: () -> Unit,
) {
    val connecting = state.connectionStatus == ConnectionStatus.CONNECTING

    AppBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .safeDrawingPadding()
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 28.dp),
            verticalArrangement = Arrangement.Center,
        ) {
            BrandMark()
            Spacer(Modifier.height(34.dp))
            Text(
                text = "Your desktop,\nat a glance.",
                style = MaterialTheme.typography.displaySmall,
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = "Connect to HardwareMon on the same local network to see its live telemetry.",
                style = MaterialTheme.typography.bodyLarge,
                color = TextSecondary,
            )
            Spacer(Modifier.height(34.dp))

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(CardNavy.copy(alpha = 0.76f), RoundedCornerShape(28.dp))
                    .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(28.dp))
                    .padding(22.dp),
            ) {
                Text("Connect to desktop", style = MaterialTheme.typography.titleLarge)
                Spacer(Modifier.height(8.dp))
                Text(
                    "Enter the address shown by your HardwareMon desktop backend.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                )
                Spacer(Modifier.height(22.dp))
                OutlinedTextField(
                    value = state.backendUrl,
                    onValueChange = onUrlChanged,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !connecting,
                    label = { Text("Backend URL") },
                    placeholder = { Text("http://192.168.1.249:8384") },
                    supportingText = { Text("Example: http://192.168.1.249:8384") },
                    singleLine = true,
                    isError = state.errorMessage != null,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Uri,
                        imeAction = ImeAction.Done,
                    ),
                    keyboardActions = KeyboardActions(onDone = { onConnect() }),
                    shape = RoundedCornerShape(16.dp),
                )

                if (state.errorMessage != null) {
                    Spacer(Modifier.height(12.dp))
                    ErrorPanel(state.errorMessage)
                }

                Spacer(Modifier.height(20.dp))
                Button(
                    onClick = onConnect,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(54.dp),
                    enabled = !connecting && state.backendUrl.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = ElectricBlue,
                        contentColor = Color(0xFF06101F),
                    ),
                    shape = RoundedCornerShape(16.dp),
                ) {
                    if (connecting) {
                        CircularProgressIndicator(
                            modifier = Modifier.padding(end = 12.dp),
                            color = Color(0xFF06101F),
                            strokeWidth = 2.dp,
                        )
                        Text("Testing connection…")
                    } else {
                        Text("Connect", fontWeight = FontWeight.Bold)
                    }
                }
            }
            Spacer(Modifier.height(22.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier
                        .background(Success.copy(alpha = 0.18f), RoundedCornerShape(50))
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                ) {
                    Text("LOCAL ONLY", color = Success, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }
                Text(
                    text = "  No account or cloud connection",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                )
            }
        }
    }
}

@Composable
private fun BrandMark() {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .background(ElectricBlue.copy(alpha = 0.16f), RoundedCornerShape(14.dp))
                .border(1.dp, ElectricBlue.copy(alpha = 0.3f), RoundedCornerShape(14.dp))
                .padding(horizontal = 12.dp, vertical = 9.dp),
        ) {
            Text("HM", color = ElectricBlue, fontWeight = FontWeight.Black, letterSpacing = 1.sp)
        }
        Text(
            text = "  HardwareMon Companion",
            style = MaterialTheme.typography.titleMedium,
        )
    }
}

@Composable
private fun ErrorPanel(message: String) {
    Text(
        text = message,
        modifier = Modifier
            .fillMaxWidth()
            .background(Danger.copy(alpha = 0.11f), RoundedCornerShape(14.dp))
            .border(1.dp, Danger.copy(alpha = 0.24f), RoundedCornerShape(14.dp))
            .padding(14.dp),
        style = MaterialTheme.typography.bodyMedium,
        color = Danger,
    )
}
