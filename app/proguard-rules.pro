# Keep native entry points and serializable models
-keepattributes Signature, InnerClasses, EnclosingMethod

-keep class com.ryu.vx.data.model.** { *; }

# Shizuku
-keep class rikka.shizuku.** { *; }
-dontwarn rikka.shizuku.**
