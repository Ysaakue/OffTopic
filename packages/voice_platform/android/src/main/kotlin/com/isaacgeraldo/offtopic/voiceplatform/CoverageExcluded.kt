package com.isaacgeraldo.offtopic.voiceplatform

/**
 * Excludes a class or function from the Kover coverage gate.
 *
 * Only for thin shells that can run exclusively on a device (for example JNI
 * `external` declarations). Every use must say why in a comment and belongs to
 * the closed exclusion list in CLAUDE.md.
 */
@Retention(AnnotationRetention.BINARY)
@Target(AnnotationTarget.CLASS, AnnotationTarget.FUNCTION)
annotation class CoverageExcluded
