package com.ryu.vx.shizuku

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.IBinder
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
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

    private val _state = MutableStateFlow<State>(State.Unavailable)
    val state: StateFlow<State> = _state

    @Volatile
    var service: IUnzipService? = null
        private set

    private var pending = CompletableDeferred<IUnzipService>()

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            service = binder?.let { IUnzipService.Stub.asInterface(it) }
            pending.complete(service!!)
            _state.value = State.Bound
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            service = null
            pending = CompletableDeferred()
            _state.value = State.Idle
        }
    }

    fun init(context: Context) {
        if (!Shizuku.pingBinder()) {
            _state.value = State.Unavailable
            return
        }
        if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
            bind(context)
        } else {
            _state.value = State.NoPermission
        }
    }

    fun requestPermission(context: Context) {
        val listener = object : Shizuku.OnRequestPermissionResultListener {
            override fun onRequestPermissionResult(requestCode: Int, grantResult: Int) {
                Shizuku.removeRequestPermissionResultListener(this)
                if (grantResult == PackageManager.PERMISSION_GRANTED) {
                    bind(context)
                } else {
                    _state.value = State.NoPermission
                }
            }
        }
        Shizuku.addRequestPermissionResultListener(listener)
        Shizuku.requestPermission(REQUEST_CODE)
    }

    fun bind(context: Context) {
        service?.let {
            _state.value = State.Bound
            return
        }
        val args = Shizuku.UserServiceArgs(
            ComponentName(context, UserService::class.java)
        )
        runCatching { Shizuku.bindUserService(args, connection) }.onFailure {
            _state.value = State.Unavailable
        }
    }

    fun unbind(context: Context) {
        val args = Shizuku.UserServiceArgs(ComponentName(context, UserService::class.java))
        runCatching { Shizuku.unbindUserService(args, connection, false) }
        service = null
        pending = CompletableDeferred()
        _state.value = State.Idle
    }

    /** Returns the bound [IUnzipService], suspending until it is connected. */
    suspend fun awaitService(): IUnzipService {
        service?.let { return it }
        return pending.await()
    }
}
