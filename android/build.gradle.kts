
import org.gradle.api.tasks.compile.JavaCompile

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

// Targeted fix for the cross-drive path issue on Windows.
// Some plugins live in the Pub cache (C:), while the project is on E:.
subprojects {
    project.evaluationDependsOn(":app")
    
    // Force all modules to compile with Java 11.
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_11.toString()
        targetCompatibility = JavaVersion.VERSION_11.toString()
    }

    // Move plugin build directories to C: drive if they are from the pub cache
    // This avoids drive-root calculation errors in Gradle.
    if (project.name != "app") {
        val userHome = System.getProperty("user.home")
        val fallbackBuildDir = file("$userHome/.flutter_builds_temp/${rootProject.name}/${project.name}")
        project.layout.buildDirectory.value(project.layout.projectDirectory.dir(fallbackBuildDir.absolutePath))
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
