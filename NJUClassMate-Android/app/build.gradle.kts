import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// 正式签名信息放在 keystore.properties 里（不进版本库）。
// 没有这个文件时只构建 debug 包，保证任何环境都能先跑起来。
val keystorePropsFile = rootProject.file("keystore.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) {
        keystorePropsFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.nju.classmate"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.nju.classmate"
        // 定 26 是为了直接用 java.time 做日期运算（周次、倒计时、跨天），
        // 不用为了兼容 24/25 引入 core library desugaring —— 少一个依赖少一个坑。
        // Android 8.0 及以上已覆盖 99%+ 的在用机型；HarmonyOS 4 的基线是 Android 12。
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        resourceConfigurations += listOf("zh", "en")
        vectorDrawables.useSupportLibrary = true
    }

    signingConfigs {
        if (keystorePropsFile.exists()) {
            create("release") {
                // 注意用 rootProject.file()：file() 是相对模块目录（app/）解析的，
                // 而密钥放在工程根目录，用 file() 会找不到。
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (keystorePropsFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        debug {
            // 刻意不加 applicationIdSuffix：
            // 加了之后 debug 和 release 是两个独立应用，桌面小组件、数据都不互通，
            // 调试时反而更麻烦。
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        buildConfig = true
    }

    packaging {
        resources.excludes += setOf("META-INF/*.kotlin_module")
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    // 后台定时刷新。"下一节课"卡片要能在不开 App 的情况下自己更新，靠它。
    implementation("androidx.work:work-runtime-ktx:2.9.0")

    // 引擎的单元测试跑在 JVM 上，不需要模拟器、不需要真机
    testImplementation("junit:junit:4.13.2")
}
