allprojects {
    repositories {
        google()
        mavenCentral()
    }
}



subprojects {
    afterEvaluate {
        val androidExt = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        androidExt?.compileSdkVersion(36)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
