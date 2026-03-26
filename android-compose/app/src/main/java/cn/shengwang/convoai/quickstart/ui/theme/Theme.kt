package cn.shengwang.convoai.quickstart.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val QuickStartColorScheme = darkColorScheme(
    primary = AccentBlue,
    onPrimary = Color.White,
    secondary = SuccessGreen,
    onSecondary = Color.White,
    tertiary = WarningAmber,
    background = BackgroundPrimary,
    onBackground = TextPrimary,
    surface = BackgroundSecondary,
    onSurface = TextPrimary,
    surfaceVariant = CardBackground,
    onSurfaceVariant = TextSubtitle,
    error = ErrorRed,
    onError = Color.White
)

@Composable
fun AgentstarterconvoaicomposeTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = QuickStartColorScheme,
        typography = Typography,
        content = content
    )
}
