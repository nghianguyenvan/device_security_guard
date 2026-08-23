package dev.vannghia.device_security_guard

import android.content.Context
import com.google.android.gms.tasks.Task
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager

internal class PlayIntegrityClient(context: Context) {
    private val manager = IntegrityManagerFactory.createStandard(context)
    private val providers =
        mutableMapOf<Long, Task<StandardIntegrityManager.StandardIntegrityTokenProvider>>()

    fun requestToken(
        cloudProjectNumber: Long,
        requestHash: String,
        onSuccess: (String) -> Unit,
        onFailure: (Exception) -> Unit,
    ) {
        provider(cloudProjectNumber)
            .addOnSuccessListener { provider ->
                val request =
                    StandardIntegrityManager.StandardIntegrityTokenRequest.builder()
                        .setRequestHash(requestHash)
                        .build()
                provider.request(request)
                    .addOnSuccessListener { token -> onSuccess(token.token()) }
                    .addOnFailureListener { error ->
                        providers.remove(cloudProjectNumber)
                        onFailure(error)
                    }
            }
            .addOnFailureListener { error ->
                providers.remove(cloudProjectNumber)
                onFailure(error)
            }
    }

    private fun provider(
        cloudProjectNumber: Long,
    ): Task<StandardIntegrityManager.StandardIntegrityTokenProvider> =
        providers.getOrPut(cloudProjectNumber) {
            val request =
                StandardIntegrityManager.PrepareIntegrityTokenRequest.builder()
                    .setCloudProjectNumber(cloudProjectNumber)
                    .build()
            manager.prepareIntegrityToken(request)
        }
}
