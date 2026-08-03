package com.ryu.vx.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class BaseStats(
    val hp: String = "",
    val mana: String = "",
    val physicalAttack: String = "",
    val physicalDefense: String = "",
    val movementSpeed: String = ""
)

@Serializable
data class HeroInfo(
    val id: Int = 0,
    val name: String = "",
    val portraitIcon: String = "",
    val price: String = "",
    val lane: String = "",
    val role: String = "",
    val specialty: String = "",
    val quote: String = "",
    val releaseDate: String = "",
    val baseStats: BaseStats = BaseStats()
)

@Serializable
data class SkillInfo(
    val name: String = "",
    val description: String = "",
    val icons: List<String> = emptyList()
)

@Serializable
data class Skill(
    @SerialName("skillCount") val skillCount: Int = 0,
    @SerialName("skillType") val skillType: List<String> = emptyList(),
    @SerialName("skillInfo") val skillInfo: List<SkillInfo> = emptyList()
)

/** A catalog skin shown in the hero screen. */
@Serializable
data class Skin(
    val name: String = "",
    val image: String = "",
    val type: String = "",
    val id: Int = 0
)

/** Default skin: its backup download URL is used for restoring. */
@Serializable
data class DefaultSkin(
    @SerialName("skinInfo") val skinInfo: Int = 0,
    val sc: String = ""
)

/** Custom skin-to-skin swap: download URL for the mod zip. */
@Serializable
data class SkinToSkin(
    @SerialName("skinInfo") val skinInfo: Int = 0,
    val sc: String = ""
)

@Serializable
data class HeroEntry(
    @SerialName("heroInfo") val heroInfo: HeroInfo = HeroInfo(),
    val skill: Skill = Skill(),
    val skins: List<Skin> = emptyList(),
    @SerialName("defaultSkins") val defaultSkins: List<DefaultSkin> = emptyList(),
    @SerialName("skinToSkin") val skinToSkin: List<List<SkinToSkin>> = emptyList()
)

/** Emotes, trails, recalls, elimination and respawn effects share this shape. */
@Serializable
data class CosmeticItem(
    val title: String = "",
    val sc: String = "",
    val img: String = ""
)

@Serializable
data class NewlyAddedSkin(
    val title: String = "",
    val sc: String = "",
    val img: String = ""
)

@Serializable
data class UpdateData(
    val title: String = "",
    val message: String = "",
    val changelog: List<String> = emptyList()
)

@Serializable
data class UpdateUrls(
    @SerialName("main_download_url") val mainDownloadUrl: String = ""
)

@Serializable
data class UpdateConstraints(
    @SerialName("min_required_version") val minRequiredVersion: String = "",
    @SerialName("force_update") val forceUpdate: Boolean = false
)

@Serializable
data class AppUpdateResponse(
    @SerialName("latest_version") val latestVersion: String = "",
    @SerialName("version_code") val versionCode: Int = 0,
    @SerialName("update_type") val updateType: String = "flexible",
    val importance: String = "high",
    @SerialName("release_date") val releaseDate: String = "",
    @SerialName("update_data") val updateData: UpdateData = UpdateData(),
    val urls: UpdateUrls = UpdateUrls(),
    val constraints: UpdateConstraints = UpdateConstraints()
)

/**
 * A user favorite: a specific skin of a hero, kept locally so it can be
 * injected/restored from the favorites tab.
 */
@Serializable
data class Favorite(
    val heroName: String = "",
    val heroId: Int = 0,
    val skinName: String = "",
    val skinImage: String = "",
    val skinSc: String = ""
)

/**
 * One file that a skin mod extracted into the game assets, with the SHA-256
 * of the file as it was written. Used by the injected-checker to detect
 * whether the mod is still applied (file present + hash matches).
 */
@Serializable
data class InjectedFile(
    val path: String = "",
    val sha256: String = ""
)

/**
 * A skin that was injected on this device, including the exact file hashes
 * recorded at injection time.
 */
@Serializable
data class InjectedSkin(
    val heroName: String = "",
    val heroId: Int = 0,
    val skinName: String = "",
    val skinImage: String = "",
    val skinSc: String = "",
    val files: List<InjectedFile> = emptyList()
)

/** Record of a skin that was injected on this device. */
@Serializable
data class History(
    val heroName: String = "",
    val skinName: String = "",
    val timestamp: Long = System.currentTimeMillis()
)
