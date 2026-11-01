package com.isaacgeraldo.offtopic.voiceplatform.system

import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowBuild
import kotlin.test.assertEquals

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [37])
class AndroidDeviceInfoProviderTest {
    @Test
    fun `reads manufacturer model and release from Build`() {
        ShadowBuild.setManufacturer("Xiaomi")
        ShadowBuild.setModel("Redmi Note 13")
        ShadowBuild.setVersionRelease("17")

        val info = AndroidDeviceInfoProvider()

        assertEquals("Xiaomi", info.manufacturer)
        assertEquals("Redmi Note 13", info.model)
        assertEquals("17", info.osVersion)
    }
}
