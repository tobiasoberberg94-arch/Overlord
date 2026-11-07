package de.overlord.tv

import android.app.Application

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        instance = this
        AdBlock.init(this)
        HostsUpdateJob.schedule(this)
    }

    companion object {
        lateinit var instance: App
            private set
    }
}
