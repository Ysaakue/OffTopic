package com.isaacgeraldo.offtopic.voiceplatform.system

import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SdkLevelTest {
    @Test
    fun `isAtLeast is true for the same level`() {
        assertTrue(SdkLevel(31).isAtLeast(31))
    }

    @Test
    fun `isAtLeast is true for a lower level`() {
        assertTrue(SdkLevel(37).isAtLeast(29))
    }

    @Test
    fun `isAtLeast is false for a higher level`() {
        assertFalse(SdkLevel(30).isAtLeast(31))
    }
}

@RunWith(RobolectricTestRunner::class)
class SdkLevelCurrentTest {
    @Test
    @Config(sdk = [29])
    fun `current reads the device API level on the minimum SDK`() {
        assertEquals(29, SdkLevel.current().value)
    }

    @Test
    @Config(sdk = [37])
    fun `current reads the device API level on the target SDK`() {
        assertEquals(37, SdkLevel.current().value)
    }
}
