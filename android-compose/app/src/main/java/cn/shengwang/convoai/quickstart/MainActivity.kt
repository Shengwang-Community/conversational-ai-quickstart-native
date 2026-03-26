package cn.shengwang.convoai.quickstart

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.core.view.WindowCompat
import cn.shengwang.convoai.quickstart.tools.PermissionHelp
import cn.shengwang.convoai.quickstart.ui.AgentChatScreen
import cn.shengwang.convoai.quickstart.ui.theme.AgentstarterconvoaicomposeTheme

class MainActivity : ComponentActivity() {
    private lateinit var permissionHelp: PermissionHelp

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        WindowCompat.getInsetsController(window, window.decorView)?.apply {
            isAppearanceLightStatusBars = false
            isAppearanceLightNavigationBars = false
        }
        permissionHelp = PermissionHelp(this)
        setContent {
            AgentstarterconvoaicomposeTheme {
                VoiceAssistantApp(
                    permissionHelp = permissionHelp
                )
            }
        }
    }
}

@Composable
fun VoiceAssistantApp(permissionHelp: PermissionHelp) {
    AgentChatScreen(permissionHelp = permissionHelp)
}
