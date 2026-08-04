class BaseStats {
  final String hp;
  final String mana;
  final String physicalAttack;
  final String physicalDefense;
  final String movementSpeed;

  const BaseStats({
    this.hp = '',
    this.mana = '',
    this.physicalAttack = '',
    this.physicalDefense = '',
    this.movementSpeed = '',
  });

  factory BaseStats.fromJson(Map<String, dynamic> json) => BaseStats(
        hp: json['hp'] as String? ?? '',
        mana: json['mana'] as String? ?? '',
        physicalAttack: json['physicalAttack'] as String? ?? '',
        physicalDefense: json['physicalDefense'] as String? ?? '',
        movementSpeed: json['movementSpeed'] as String? ?? '',
      );
}

class HeroInfo {
  final int id;
  final String name;
  final String portraitIcon;
  final String price;
  final String lane;
  final String role;
  final String specialty;
  final String quote;
  final String releaseDate;
  final BaseStats baseStats;

  const HeroInfo({
    this.id = 0,
    this.name = '',
    this.portraitIcon = '',
    this.price = '',
    this.lane = '',
    this.role = '',
    this.specialty = '',
    this.quote = '',
    this.releaseDate = '',
    this.baseStats = const BaseStats(),
  });

  factory HeroInfo.fromJson(Map<String, dynamic> json) => HeroInfo(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        portraitIcon: json['portraitIcon'] as String? ?? '',
        price: json['price'] as String? ?? '',
        lane: json['lane'] as String? ?? '',
        role: json['role'] as String? ?? '',
        specialty: json['specialty'] as String? ?? '',
        quote: json['quote'] as String? ?? '',
        releaseDate: json['releaseDate'] as String? ?? '',
        baseStats: json['baseStats'] is Map<String, dynamic>
            ? BaseStats.fromJson(json['baseStats'] as Map<String, dynamic>)
            : const BaseStats(),
      );
}

class SkillInfo {
  final String name;
  final String description;
  final List<String> icons;

  const SkillInfo({
    this.name = '',
    this.description = '',
    this.icons = const [],
  });

  factory SkillInfo.fromJson(Map<String, dynamic> json) => SkillInfo(
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        icons: (json['icons'] as List?)?.cast<String>() ?? const [],
      );
}

class Skill {
  final int skillCount;
  final List<String> skillType;
  final List<SkillInfo> skillInfo;

  const Skill({
    this.skillCount = 0,
    this.skillType = const [],
    this.skillInfo = const [],
  });

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
        skillCount: json['skillCount'] as int? ?? 0,
        skillType: (json['skillType'] as List?)?.cast<String>() ?? const [],
        skillInfo: (json['skillInfo'] as List? ?? const [])
            .map((e) => SkillInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Skin {
  final String name;
  final String image;
  final String type;
  final int id;

  const Skin({
    this.name = '',
    this.image = '',
    this.type = '',
    this.id = 0,
  });

  factory Skin.fromJson(Map<String, dynamic> json) => Skin(
        name: json['name'] as String? ?? '',
        image: json['image'] as String? ?? '',
        type: json['type'] as String? ?? '',
        id: json['id'] as int? ?? 0,
      );
}

class DefaultSkin {
  final int skinInfo;
  final String sc;

  const DefaultSkin({this.skinInfo = 0, this.sc = ''});

  factory DefaultSkin.fromJson(Map<String, dynamic> json) => DefaultSkin(
        skinInfo: json['skinInfo'] as int? ?? 0,
        sc: json['sc'] as String? ?? '',
      );
}

class SkinToSkin {
  final int skinInfo;
  final String sc;

  const SkinToSkin({this.skinInfo = 0, this.sc = ''});

  factory SkinToSkin.fromJson(Map<String, dynamic> json) => SkinToSkin(
        skinInfo: json['skinInfo'] as int? ?? 0,
        sc: json['sc'] as String? ?? '',
      );
}

class HeroEntry {
  final HeroInfo heroInfo;
  final Skill skill;
  final List<Skin> skins;
  final List<DefaultSkin> defaultSkins;
  final List<List<SkinToSkin>> skinToSkin;

  const HeroEntry({
    this.heroInfo = const HeroInfo(),
    this.skill = const Skill(),
    this.skins = const [],
    this.defaultSkins = const [],
    this.skinToSkin = const [],
  });

  factory HeroEntry.fromJson(Map<String, dynamic> json) => HeroEntry(
        heroInfo: json['heroInfo'] is Map<String, dynamic>
            ? HeroInfo.fromJson(json['heroInfo'] as Map<String, dynamic>)
            : const HeroInfo(),
        skill: json['skill'] is Map<String, dynamic>
            ? Skill.fromJson(json['skill'] as Map<String, dynamic>)
            : const Skill(),
        skins: (json['skins'] as List? ?? const [])
            .map((e) => Skin.fromJson(e as Map<String, dynamic>))
            .toList(),
        defaultSkins: (json['defaultSkins'] as List? ?? const [])
            .map((e) => DefaultSkin.fromJson(e as Map<String, dynamic>))
            .toList(),
        skinToSkin: (json['skinToSkin'] as List? ?? const [])
            .map((group) => (group as List)
                .map((e) => SkinToSkin.fromJson(e as Map<String, dynamic>))
                .toList())
            .toList(),
      );
}

class CosmeticItem {
  final String title;
  final String sc;
  final String img;

  const CosmeticItem({this.title = '', this.sc = '', this.img = ''});

  factory CosmeticItem.fromJson(Map<String, dynamic> json) => CosmeticItem(
        title: json['title'] as String? ?? '',
        sc: json['sc'] as String? ?? '',
        img: json['img'] as String? ?? '',
      );
}

class Favorite {
  final String heroName;
  final int heroId;
  final String skinName;
  final String skinImage;
  final String skinSc;

  const Favorite({
    this.heroName = '',
    this.heroId = 0,
    this.skinName = '',
    this.skinImage = '',
    this.skinSc = '',
  });

  factory Favorite.fromJson(Map<String, dynamic> json) => Favorite(
        heroName: json['heroName'] as String? ?? '',
        heroId: json['heroId'] as int? ?? 0,
        skinName: json['skinName'] as String? ?? '',
        skinImage: json['skinImage'] as String? ?? '',
        skinSc: json['skinSc'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'heroName': heroName,
        'heroId': heroId,
        'skinName': skinName,
        'skinImage': skinImage,
        'skinSc': skinSc,
      };
}

class InjectedFile {
  final String path;
  final String sha256;

  const InjectedFile({this.path = '', this.sha256 = ''});

  factory InjectedFile.fromJson(Map<String, dynamic> json) => InjectedFile(
        path: json['path'] as String? ?? '',
        sha256: json['sha256'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'path': path, 'sha256': sha256};
}

class InjectedSkin {
  final String heroName;
  final int heroId;
  final String skinName;
  final String skinImage;
  final String skinSc;
  final List<InjectedFile> files;

  const InjectedSkin({
    this.heroName = '',
    this.heroId = 0,
    this.skinName = '',
    this.skinImage = '',
    this.skinSc = '',
    this.files = const [],
  });

  factory InjectedSkin.fromJson(Map<String, dynamic> json) => InjectedSkin(
        heroName: json['heroName'] as String? ?? '',
        heroId: json['heroId'] as int? ?? 0,
        skinName: json['skinName'] as String? ?? '',
        skinImage: json['skinImage'] as String? ?? '',
        skinSc: json['skinSc'] as String? ?? '',
        files: (json['files'] as List? ?? const [])
            .map((e) => InjectedFile.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'heroName': heroName,
        'heroId': heroId,
        'skinName': skinName,
        'skinImage': skinImage,
        'skinSc': skinSc,
        'files': files.map((f) => f.toJson()).toList(),
      };
}

class History {
  final String heroName;
  final String skinName;
  final int timestamp;

  const History({
    this.heroName = '',
    this.skinName = '',
    this.timestamp = 0,
  });

  factory History.fromJson(Map<String, dynamic> json) => History(
        heroName: json['heroName'] as String? ?? '',
        skinName: json['skinName'] as String? ?? '',
        timestamp: json['timestamp'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'heroName': heroName,
        'skinName': skinName,
        'timestamp': timestamp,
      };
}

class GameTarget {
  final String packageName;
  final String assetsDir;
  final String dataDir;

  const GameTarget({
    this.packageName = '',
    this.assetsDir = '',
    this.dataDir = '',
  });

  factory GameTarget.fromMap(Map<dynamic, dynamic> map) => GameTarget(
        packageName: map['packageName'] as String? ?? '',
        assetsDir: map['assetsDir'] as String? ?? '',
        dataDir: map['dataDir'] as String? ?? '',
      );
}
