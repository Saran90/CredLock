package com.credlock.credlock

import android.content.Context
import android.os.Build

class AutofillHelper(private val context: Context) {
    
    fun isAutofillEnabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val autofillManager = context.getSystemService("autofill")
                autofillManager != null
            } catch (e: Exception) {
                false
            }
        } else {
            false
        }
    }

    fun enableAutofill(): Boolean {
        return true
    }

    fun disableAutofill(): Boolean {
        return true
    }
}
