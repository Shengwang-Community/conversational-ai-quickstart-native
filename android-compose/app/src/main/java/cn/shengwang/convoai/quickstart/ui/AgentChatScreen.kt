package cn.shengwang.convoai.quickstart.ui

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import cn.shengwang.convoai.quickstart.R
import io.agora.convoai.convoaiApi.AgentState
import io.agora.convoai.convoaiApi.Transcript
import io.agora.convoai.convoaiApi.TranscriptType
import cn.shengwang.convoai.quickstart.tools.PermissionHelp
import cn.shengwang.convoai.quickstart.ui.theme.AccentBlue
import cn.shengwang.convoai.quickstart.ui.theme.AccentBlueDark
import cn.shengwang.convoai.quickstart.ui.theme.BackgroundPrimary
import cn.shengwang.convoai.quickstart.ui.theme.BackgroundSecondary
import cn.shengwang.convoai.quickstart.ui.theme.BorderDefault
import cn.shengwang.convoai.quickstart.ui.theme.BubbleAgentBackground
import cn.shengwang.convoai.quickstart.ui.theme.BubbleAgentText
import cn.shengwang.convoai.quickstart.ui.theme.BubbleUserBackground
import cn.shengwang.convoai.quickstart.ui.theme.BubbleUserText
import cn.shengwang.convoai.quickstart.ui.theme.ButtonDisabledBackground
import cn.shengwang.convoai.quickstart.ui.theme.ButtonDisabledText
import cn.shengwang.convoai.quickstart.ui.theme.ControlBarBackground
import cn.shengwang.convoai.quickstart.ui.theme.ErrorRed
import cn.shengwang.convoai.quickstart.ui.theme.ErrorRedLight
import cn.shengwang.convoai.quickstart.ui.theme.LogContentBackground
import cn.shengwang.convoai.quickstart.ui.theme.LogOuterBackground
import cn.shengwang.convoai.quickstart.ui.theme.MicMutedBackground
import cn.shengwang.convoai.quickstart.ui.theme.MicMutedIcon
import cn.shengwang.convoai.quickstart.ui.theme.MicNormalBackground
import cn.shengwang.convoai.quickstart.ui.theme.MicNormalIcon
import cn.shengwang.convoai.quickstart.ui.theme.StateIdle
import cn.shengwang.convoai.quickstart.ui.theme.StateListening
import cn.shengwang.convoai.quickstart.ui.theme.StateSilent
import cn.shengwang.convoai.quickstart.ui.theme.StateSpeaking
import cn.shengwang.convoai.quickstart.ui.theme.StateThinking
import cn.shengwang.convoai.quickstart.ui.theme.SuccessGreen
import cn.shengwang.convoai.quickstart.ui.theme.SuccessGreenLight
import cn.shengwang.convoai.quickstart.ui.theme.TextPrimary
import cn.shengwang.convoai.quickstart.ui.theme.TextSecondary
import cn.shengwang.convoai.quickstart.ui.theme.TextSubtitle
import cn.shengwang.convoai.quickstart.ui.theme.TextTertiary
import cn.shengwang.convoai.quickstart.ui.theme.WarningAmberLight
import kotlinx.coroutines.launch

@Composable
fun AgentChatScreen(
    viewModel: AgentChatViewModel = viewModel(),
    permissionHelp: PermissionHelp
) {
    val context = LocalContext.current
    val activity = context as? Activity
    val uiState by viewModel.uiState.collectAsState()
    val transcriptList by viewModel.transcriptList.collectAsState()
    val agentState by viewModel.agentState.collectAsState()
    val debugLogList by viewModel.debugLogList.collectAsState()
    val resolvedAgentState = agentState ?: AgentState.IDLE

    val listState = rememberLazyListState()
    val logScrollState = rememberScrollState()
    val scope = rememberCoroutineScope()

    var showPermissionDialog by remember { mutableStateOf(false) }
    var autoScrollToBottom by remember { mutableStateOf(true) }

    BackHandler {
        activity?.finish()
    }

    LaunchedEffect(listState.isScrollInProgress) {
        if (!listState.isScrollInProgress && !listState.canScrollForward) {
            autoScrollToBottom = true
        }
    }

    LaunchedEffect(listState.firstVisibleItemIndex, listState.firstVisibleItemScrollOffset) {
        if (listState.isScrollInProgress && listState.canScrollForward) {
            autoScrollToBottom = false
        }
    }

    LaunchedEffect(transcriptList) {
        if (transcriptList.isNotEmpty() && autoScrollToBottom) {
            scope.launch {
                scrollToBottom(listState, transcriptList.size)
            }
        }
    }

    LaunchedEffect(debugLogList) {
        if (debugLogList.isNotEmpty()) {
            scope.launch {
                logScrollState.animateScrollTo(logScrollState.maxValue)
            }
        }
    }

    val gradientBrush = Brush.verticalGradient(
        colors = listOf(
            BackgroundPrimary,
            BackgroundSecondary,
            BackgroundPrimary
        )
    )

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        containerColor = Color.Transparent,
        contentWindowInsets = WindowInsets(0.dp)
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .background(gradientBrush)
                .windowInsetsPadding(WindowInsets.statusBars)
                .windowInsetsPadding(WindowInsets.navigationBars)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp)
            ) {
                HeaderSection()
                Spacer(modifier = Modifier.height(8.dp))
                LogSection(logs = debugLogList, scrollState = logScrollState)
                Spacer(modifier = Modifier.height(8.dp))
                TranscriptSection(
                    transcriptList = transcriptList,
                    listState = listState,
                    agentState = resolvedAgentState,
                    modifier = Modifier.weight(1f)
                )
                Spacer(modifier = Modifier.height(16.dp))
                ControlSection(
                    uiState = uiState,
                    onStart = {
                        val channelName = AgentChatViewModel.generateRandomChannelName()
                        if (permissionHelp.hasMicPerm()) {
                            viewModel.joinChannelAndLogin(channelName)
                        } else {
                            permissionHelp.checkMicPerm(
                                granted = { viewModel.joinChannelAndLogin(channelName) },
                                unGranted = { showPermissionDialog = true }
                            )
                        }
                    },
                    onToggleMute = viewModel::toggleMute,
                    onHangup = viewModel::hangup
                )
            }
        }
    }

    if (showPermissionDialog) {
        AlertDialog(
            onDismissRequest = { showPermissionDialog = false },
            containerColor = BackgroundSecondary,
            titleContentColor = TextPrimary,
            textContentColor = TextSubtitle,
            title = { Text("Permission Required") },
            text = { Text("Microphone permission is required for voice chat. Please grant the permission to continue.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showPermissionDialog = false
                        permissionHelp.launchAppSettingForMic(
                            granted = {
                                val channelName = AgentChatViewModel.generateRandomChannelName()
                                viewModel.joinChannelAndLogin(channelName)
                            },
                            unGranted = { }
                        )
                    }
                ) {
                    Text("Retry", color = AccentBlue)
                }
            },
            dismissButton = {
                TextButton(onClick = { showPermissionDialog = false }) {
                    Text("Exit", color = TextSubtitle)
                }
            }
        )
    }
}

@Composable
private fun HeaderSection() {
    Text(
        text = "Shengwang Conversational AI",
        style = MaterialTheme.typography.headlineSmall,
        color = TextPrimary
    )
    Text(
        text = "Real-time Voice Conversation Demo",
        style = MaterialTheme.typography.bodySmall,
        color = TextSubtitle
    )
}

@Composable
private fun LogSection(logs: List<String>, scrollState: ScrollState) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(120.dp)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = LogOuterBackground),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(LogContentBackground)
                .padding(12.dp)
        ) {
            Text(
                text = buildLogText(logs),
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(scrollState),
                style = MaterialTheme.typography.labelSmall.copy(
                    fontFamily = FontFamily.Monospace,
                    lineHeight = 16.sp
                )
            )
        }
    }
}

@Composable
private fun TranscriptSection(
    transcriptList: List<Transcript>,
    listState: LazyListState,
    agentState: AgentState,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = BackgroundSecondary.copy(alpha = 0.5f)),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            LazyColumn(
                state = listState,
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(transcriptList) { transcript ->
                    TranscriptItem(transcript = transcript)
                }
            }
            AgentStatusBar(agentState = agentState)
        }
    }
}

@Composable
private fun AgentStatusBar(agentState: AgentState) {
    val stateColor = agentStateColor(agentState)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(ControlBarBackground)
            .padding(12.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(stateColor)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = agentState.value.replaceFirstChar { it.uppercase() },
            style = MaterialTheme.typography.labelMedium,
            color = stateColor
        )
    }
}

@Composable
private fun ControlSection(
    uiState: AgentChatViewModel.ConversationUiState,
    onStart: () -> Unit,
    onToggleMute: () -> Unit,
    onHangup: () -> Unit
) {
    val isConnected = uiState.connectionState == AgentChatViewModel.ConnectionState.Connected
    val isConnecting = uiState.connectionState == AgentChatViewModel.ConnectionState.Connecting
    val isError = uiState.connectionState == AgentChatViewModel.ConnectionState.Error

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (isConnected) {
            Button(
                onClick = onToggleMute,
                modifier = Modifier.size(56.dp),
                shape = CircleShape,
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (uiState.isMuted) MicMutedBackground else MicNormalBackground,
                    contentColor = if (uiState.isMuted) MicMutedIcon else MicNormalIcon
                ),
                contentPadding = PaddingValues(0.dp)
            ) {
                Icon(
                    painter = painterResource(if (uiState.isMuted) R.drawable.ic_mic_off else R.drawable.ic_mic),
                    contentDescription = if (uiState.isMuted) "Unmute" else "Mute"
                )
            }

            Spacer(modifier = Modifier.width(24.dp))

            Button(
                onClick = onHangup,
                modifier = Modifier
                    .weight(1f)
                    .height(56.dp),
                shape = RoundedCornerShape(8.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = ErrorRed,
                    contentColor = Color.White
                )
            ) {
                Text("Stop Agent", style = MaterialTheme.typography.titleMedium)
            }
        } else {
            val startBrush = when {
                isConnecting -> null
                isError -> null
                else -> Brush.horizontalGradient(listOf(AccentBlueDark, AccentBlue))
            }
            val startColor = when {
                isConnecting -> ButtonDisabledBackground
                isError -> ErrorRed
                else -> Color.Transparent
            }
            val textColor = when {
                isConnecting -> ButtonDisabledText
                else -> Color.White
            }

            Button(
                onClick = onStart,
                enabled = !isConnecting,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(8.dp),
                contentPadding = PaddingValues(0.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Transparent,
                    disabledContainerColor = Color.Transparent
                )
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            brush = startBrush ?: Brush.horizontalGradient(listOf(startColor, startColor)),
                            shape = RoundedCornerShape(8.dp)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = when {
                            isConnecting -> "Connecting..."
                            isError -> "Retry"
                            else -> "Start Agent"
                        },
                        style = MaterialTheme.typography.titleMedium,
                        color = textColor
                    )
                }
            }
        }
    }
}

@Composable
private fun TranscriptItem(transcript: Transcript) {
    val isUser = transcript.type == TranscriptType.USER
    val bubbleShape = if (isUser) {
        RoundedCornerShape(topStart = 16.dp, topEnd = 2.dp, bottomStart = 16.dp, bottomEnd = 16.dp)
    } else {
        RoundedCornerShape(topStart = 2.dp, topEnd = 16.dp, bottomStart = 16.dp, bottomEnd = 16.dp)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
        verticalAlignment = Alignment.Top
    ) {
        if (!isUser) {
            Avatar(text = "AI", background = AccentBlue)
            Spacer(modifier = Modifier.width(8.dp))
        }

        Box(
            modifier = Modifier
                .widthIn(max = 280.dp)
                .clip(bubbleShape)
                .background(if (isUser) BubbleUserBackground else BubbleAgentBackground)
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            Text(
                text = transcript.text.ifEmpty { "..." },
                style = MaterialTheme.typography.bodyMedium,
                color = if (isUser) BubbleUserText else BubbleAgentText
            )
        }

        if (isUser) {
            Spacer(modifier = Modifier.width(8.dp))
            Avatar(text = "Me", background = SuccessGreen)
        }
    }
}

@Composable
private fun Avatar(text: String, background: Color) {
    Box(
        modifier = Modifier
            .size(32.dp)
            .clip(CircleShape)
            .background(background),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            color = Color.White,
            style = MaterialTheme.typography.labelSmall,
            textAlign = TextAlign.Center
        )
    }
}

private fun agentStateColor(agentState: AgentState): Color {
    return when (agentState) {
        AgentState.IDLE -> StateIdle
        AgentState.LISTENING -> StateListening
        AgentState.THINKING -> StateThinking
        AgentState.SPEAKING -> StateSpeaking
        AgentState.SILENT -> StateSilent
        AgentState.UNKNOWN -> TextTertiary
    }
}

private fun buildLogText(logs: List<String>): AnnotatedString {
    if (logs.isEmpty()) {
        return buildAnnotatedString {
            pushStyle(SpanStyle(color = TextSecondary))
            append("log")
            pop()
        }
    }

    return buildAnnotatedString {
        logs.forEachIndexed { index, log ->
            val color = when {
                log.contains("failed", ignoreCase = true) || log.contains("error", ignoreCase = true) -> ErrorRedLight
                log.contains("successfully", ignoreCase = true) || log.contains("success", ignoreCase = true) -> SuccessGreenLight
                log.contains("connecting", ignoreCase = true) || log.contains("starting", ignoreCase = true) -> WarningAmberLight
                else -> TextSecondary
            }
            pushStyle(SpanStyle(color = color))
            append(log)
            pop()
            if (index < logs.lastIndex) {
                append("\n")
            }
        }
    }
}

private suspend fun scrollToBottom(listState: LazyListState, itemCount: Int) {
    val lastPosition = itemCount - 1
    if (lastPosition < 0) return

    listState.scrollToItem(lastPosition)
    val layoutInfo = listState.layoutInfo
    val lastVisibleItem = layoutInfo.visibleItemsInfo.lastOrNull()
    if (lastVisibleItem != null && lastVisibleItem.index == lastPosition) {
        val viewportHeight = layoutInfo.viewportEndOffset - layoutInfo.viewportStartOffset
        val itemEndOffset = lastVisibleItem.offset + lastVisibleItem.size
        if (itemEndOffset > layoutInfo.viewportEndOffset) {
            val offset = viewportHeight - lastVisibleItem.size
            if (offset < 0) {
                listState.scrollToItem(lastPosition, scrollOffset = offset)
            }
        }
    }
}
