import org.gradle.api.file.Directory
import org.gradle.api.tasks.compile.JavaCompile
import com.android.build.gradle.LibraryExtension
import com.android.build.gradle.AppExtension

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
    pluginManager.withPlugin("com.android.library") {
        extensions.findByType<com.android.build.gradle.LibraryExtension>()?.let {
            if (it.namespace == null) {
                // Specific fix for flutter_app_badger which uses this specific package name
                if (project.name == "flutter_app_badger") {
                    it.namespace = "fr.g123k.flutterappbadge.flutterappbadger"
                } else {
                    it.namespace = "com.missing.namespace.${project.name.replace(":", ".").replace("-", ".")}"
                }
            }
        }
    }
    pluginManager.withPlugin("com.android.application") {
        extensions.findByType<com.android.build.gradle.AppExtension>()?.let {
            if (it.namespace == null) {
                it.namespace = "com.missing.namespace.${project.name.replace(":", ".").replace("-", ".")}"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

