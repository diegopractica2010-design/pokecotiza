# ML Kit: el plugin hace referencia a los modelos chino, devanagari, japonés y
# coreano. Solo se incluye el japonés (y el latino viene por defecto); los
# demás faltan a propósito y R8 no debe fallar por eso.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.korean.**
