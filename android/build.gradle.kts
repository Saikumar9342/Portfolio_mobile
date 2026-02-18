import org.gradle.api.file.Directory
import org.gradle.api.tasks.compile.JavaCompile
import com.android.build.api.dsl.LibraryExtension
import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.variant.LibraryAndroidComponentsExtension

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")

    // Keep Java compile targets aligned across plugin subprojects.
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
        options.compilerArgs.add("-Xlint:-options")
    }


    // Workaround for plugins with missing namespaces (AGP 8.0 requirement)
    // and force compileSdk 34 for old plugins setting it lower (e.g. flutter_app_badger sets 28)
    // Workaround for plugins with missing namespaces (AGP 8.0 requirement)
    // and force compileSdk 34 for old plugins setting it lower (e.g. flutter_app_badger sets 28)
    pluginManager.withPlugin("com.android.library") {
        val androidComponents = extensions.findByType<LibraryAndroidComponentsExtension>()
        androidComponents?.finalizeDsl { extension ->
            // Apply strict fixes only for flutter_app_badger which is known to be outdated
            if (project.name == "flutter_app_badger") {
                extension.compileSdk = 34
                extension.defaultConfig.targetSdk = 34
                if (extension.defaultConfig.minSdk == null || extension.defaultConfig.minSdk!! < 21) {
                    extension.defaultConfig.minSdk = 21
                }
                if (extension.namespace == null) {
                    extension.namespace = "fr.g123k.flutterappbadge.flutterappbadger"
                }
            } else if (extension.namespace == null) {
                 // Only fix namespace for others if absolutely missing (unlikely for modern plugins)
                 extension.namespace = "com.missing.namespace.${project.name.replace(":", ".").replace("-", ".")}"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

