import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.androidx.navigation.safe.args)
}

// Load env.properties file for ShengWang configuration
val envProperties = Properties()
val envPropertiesFile = rootProject.file("env.properties")
if (envPropertiesFile.exists()) {
    envPropertiesFile.inputStream().use { envProperties.load(it) }
}

// Validate required ShengWang configuration properties
val requiredProperties = listOf(
    "APP_ID",
    "APP_CERTIFICATE",
    "LLM_API_KEY",
    "LLM_URL",
    "LLM_MODEL",
    "STT_MICROSOFT_KEY",
    "TTS_MINIMAX_KEY",
    "TTS_MINIMAX_GROUP_ID"
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
    compileSdk = 36

    buildFeatures {
        viewBinding = true
        buildConfig = true
    }

    defaultConfig {
        applicationId = "cn.shengwang.convoai.quickstart.kotlin"
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
        buildConfigField("String", "LLM_URL", "\"${envProperties.getProperty("LLM_URL", "https://api.deepseek.com/v1/chat/completions")}\"")
        buildConfigField("String", "LLM_MODEL", "\"${envProperties.getProperty("LLM_MODEL", "deepseek-chat")}\"")

        // STT configuration
        buildConfigField("String", "STT_MICROSOFT_KEY", "\"${envProperties.getProperty("STT_MICROSOFT_KEY", "")}\"")
        buildConfigField("String", "STT_MICROSOFT_REGION", "\"${envProperties.getProperty("STT_MICROSOFT_REGION", "chinaeast2")}\"")

        // TTS configuration
        buildConfigField("String", "TTS_MINIMAX_KEY", "\"${envProperties.getProperty("TTS_MINIMAX_KEY", "")}\"")
        buildConfigField("String", "TTS_MINIMAX_MODEL", "\"${envProperties.getProperty("TTS_MINIMAX_MODEL", "speech-01-turbo")}\"")
        buildConfigField("String", "TTS_MINIMAX_VOICE_ID", "\"${envProperties.getProperty("TTS_MINIMAX_VOICE_ID", "male-qn-qingse")}\"")
        buildConfigField("String", "TTS_MINIMAX_GROUP_ID", "\"${envProperties.getProperty("TTS_MINIMAX_GROUP_ID", "")}\"")
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
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.androidx.constraintlayout)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)

    implementation(libs.okhttp.core)
    implementation(libs.okhttp.logging.interceptor)
    implementation(libs.retrofit)
    implementation(libs.converter.gson)
    implementation(libs.gson)
    implementation(libs.agora.rtc)
    implementation(libs.agora.rtm)
    
    // Kotlin Coroutines
    implementation(libs.kotlinx.coroutines.android)
    
    // Lifecycle components
    implementation(libs.androidx.lifecycle.viewmodel)
    implementation(libs.androidx.lifecycle.livedata)
    
    // RecyclerView
    implementation(libs.androidx.recyclerview)
    
    // Navigation Component
    implementation(libs.androidx.navigation.fragment)
    implementation(libs.androidx.navigation.ui)
}