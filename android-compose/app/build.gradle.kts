import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

// Load env.properties file for ShengWang configuration
val envProperties = Properties()
val envPropertiesFile = rootProject.file("env.properties")
if (envPropertiesFile.exists()) {
    envPropertiesFile.inputStream().use { envProperties.load(it) }
}

// Validate required ShengWang configuration properties
// APP_CERTIFICATE is required because this project uses HTTP token auth
// ("Authorization: agora token=<token>") for REST API calls.
val requiredProperties = listOf(
    "APP_ID",
    "APP_CERTIFICATE",
    "LLM_API_KEY",
    "TTS_BYTEDANCE_APP_ID",
    "TTS_BYTEDANCE_TOKEN"
)

val missingProperties = mutableListOf<String>()
requiredProperties.forEach { key ->
    val value = envProperties.getProperty(key)
    if (value.isNullOrEmpty()) {
        missingProperties.add(key)
    }
}

if (missingProperties.isNotEmpty()) {
    val errorMessage = buildString {
        append("Please configure the following required properties in env.properties:\n")
        missingProperties.forEach { prop ->
            append("  - $prop\n")
        }
        append("\nPlease refer to env.properties for configuration reference.")
    }
    throw GradleException(errorMessage)
}

android {
    namespace = "cn.shengwang.convoai.quickstart"
    compileSdk {
        version = release(36)
    }

    defaultConfig {
        applicationId = "cn.shengwang.convoai.quickstart.compose"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        // Load ShengWang configuration from env.properties
        buildConfigField("String", "APP_ID", "\"${envProperties.getProperty("APP_ID", "")}\"")
        buildConfigField("String", "APP_CERTIFICATE", "\"${envProperties.getProperty("APP_CERTIFICATE", "")}\"")

        // LLM configuration
        buildConfigField("String", "LLM_API_KEY", "\"${envProperties.getProperty("LLM_API_KEY", "")}\"")
        buildConfigField("String", "LLM_URL", "\"${envProperties.getProperty("LLM_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")}\"")
        buildConfigField("String", "LLM_MODEL", "\"${envProperties.getProperty("LLM_MODEL", "qwen-plus")}\"")

        // TTS configuration
        buildConfigField("String", "TTS_BYTEDANCE_APP_ID", "\"${envProperties.getProperty("TTS_BYTEDANCE_APP_ID", "")}\"")
        buildConfigField("String", "TTS_BYTEDANCE_TOKEN", "\"${envProperties.getProperty("TTS_BYTEDANCE_TOKEN", "")}\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material3.adaptive.navigation.suite)

    // Shengwang SDKs
    implementation(libs.shengwang.rtc.full)
    implementation(libs.shengwang.rtm.lite)
    
    // Network
    implementation(libs.okhttp.core)
    implementation(libs.okhttp.logging.interceptor)
    implementation(libs.retrofit)
    implementation(libs.converter.gson)
    implementation(libs.gson)
    
    // Coroutines
    implementation(libs.kotlinx.coroutines.android)
    
    // Lifecycle & ViewModel
    implementation(libs.androidx.lifecycle.viewmodel)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    
    // Navigation
    implementation(libs.androidx.navigation.compose)
    
    testImplementation(libs.junit)
    testImplementation("org.json:json:20240303")
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
