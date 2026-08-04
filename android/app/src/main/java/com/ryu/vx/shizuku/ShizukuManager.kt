package com.ryu.vx.shizuku

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.IBinder
import kotlinx.coroutines.CompletableDeferred
import rikka.shizuku.Shizuku

/**
 * Owns the Shizuku connection used for privileged file operations.
 */
object ShizukuManager {

    private const val REQUEST_CODE = 1001

    sealed class State {
        data object Unavailable : State()
        data object NoPermission : State()
        data object Idle : State()
        data object Bound : State()
    }

    @Volatile
    private var _state: State = State.Unavailable
    val state: State get() = _state

    @Volatile
    var service: IUnzipService? = null
        private set

    private var pending = CompletableDeferred<IUnzipService>()

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            service = binder?.let { IUnzipService.Stub.asInterface(it) }
            pending.complete(service!!)
            _state = State.Bound
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            service = null
            pending = CompletableDeferred()
            _state = State.Idle
        }
    }

    fun init(context: Context) {
        if (!Shizuku.pingBinder()) {
            _state = State.Unavailable
            return
        }
        if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
            bind(context)
        } else {
            _state = State.NoPermission
        }
    }

    fun requestPermission(context: Context) {
        val listener = object : Shizuku.OnRequestPermissionResultListener {
            override fun onRequestPermissionResult(requestCode: Int, grantResult: Int) {
                Shizuku.removeRequestPermissionResultListener(this)
                if (grantResult == PackageManager.PERMISSION_GRANTED) {
                    bind(context)
                } else {
                    _state = State.NoPermission
                }
            }
        }
        Shizuku.addRequestPermissionResultListener(listener)
        Shizuku.requestPermission(REQUEST_CODE)
    }

    fun bind(context: Context) {
        service?.let {
            _state = State.Bound
            return
        }
        val args = Shizuku.UserServiceArgs(ComponentName(context, UserService::class.java))
        runCatching { Shizuku.bindUserService(args, connection) }.onFailure {
            _state = State.Unavailable
        }
    }

    /** Returns the bound [IUnzipService], suspending until connected. */
    suspend fun awaitService(): IUnzipService {
        service?.let { return it }
        return pending.await()
    }
}
