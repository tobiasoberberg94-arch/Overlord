package de.overlord.tv

import android.app.Activity
import android.app.Application
import android.os.Bundle
import java.lang.ref.WeakReference

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        instance = this
        Fonts.init(this)
        ImageLoader.init(this)
        AdBlock.init(this)
        HostsUpdateJob.schedule(this)
        if (PhoneRemote.enabled) PhoneRemote.start()

        // Sichtbare Activity merken (für den Handy-Begleiter)
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityResumed(a: Activity) { currentRef = WeakReference(a) }
            override fun onActivityPaused(a: Activity) { if (currentRef?.get() === a) currentRef = null }
            override fun onActivityCreated(a: Activity, b: Bundle?) {}
            override fun onActivityStarted(a: Activity) {}
            override fun onActivityStopped(a: Activity) {}
            override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
            override fun onActivityDestroyed(a: Activity) {}
        })
    }

    companion object {
        lateinit var instance: App
            private set

        @Volatile
        private var currentRef: WeakReference<Activity>? = null

        /** Die gerade sichtbare Activity (oder null, wenn die App im Hintergrund ist). */
        val current: Activity? get() = currentRef?.get()
    }
}
