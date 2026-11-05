import kotlinx.kover.gradle.plugin.dsl.CoverageUnit
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

group = "com.isaacgeraldo.offtopic.voiceplatform"
version = "0.1.0"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:9.1.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlinx.kover") version "0.9.11"
    id("org.jlleitschuh.gradle.ktlint") version "14.2.0"
}

android {
    namespace = "com.isaacgeraldo.offtopic.voiceplatform"
    compileSdk = 37

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 29
        consumerProguardFiles("consumer-rules.pro")
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.testLogging {
                    events("passed", "skipped", "failed")
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    implementation("androidx.core:core-telecom:1.1.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit")
    testImplementation("io.mockk:mockk:1.14.11")
    testImplementation("org.robolectric:robolectric:4.17")
    testImplementation("androidx.test:core:1.7.0")
    testImplementation("androidx.test.ext:junit:1.3.0")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")
}

tasks.withType<Test>().configureEach {
    // Robolectric's SDK 37 sandbox reflects into java.io.FileDescriptor through
    // jdk.internal.access.SharedSecrets.
    jvmArgs(
        "--add-opens=java.base/java.io=ALL-UNNAMED",
        "--add-exports=java.base/jdk.internal.access=ALL-UNNAMED",
    )
    doFirst {
        check(JavaVersion.current().isCompatibleWith(JavaVersion.VERSION_21)) {
            "Robolectric for SDK 37 needs Java 21, but Gradle runs on ${JavaVersion.current()}. " +
                "Run tools/verify.ps1, or point JAVA_HOME to the JDK reported by `fvm flutter doctor -v`."
        }
    }
}

ktlint {
    version.set("1.8.0")
    filter {
        exclude { it.file.path.contains("generated") }
    }
}

kover {
    reports {
        filters {
            excludes {
                packages("com.isaacgeraldo.offtopic.voiceplatform.generated")
                annotatedBy("com.isaacgeraldo.offtopic.voiceplatform.CoverageExcluded")
            }
        }
        verify {
            rule("Line coverage") {
                minBound(90, CoverageUnit.LINE)
            }
            rule("Branch coverage") {
                minBound(85, CoverageUnit.BRANCH)
            }
        }
    }
}
