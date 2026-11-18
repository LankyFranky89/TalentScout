-- Talent Scout builds. Each entry: "Talent Name:ranks" in the order to take them.
-- Edit freely; /tscout check reports any names the game doesn't recognise.
TalentScout_Builds = {
  WARRIOR = {
    { role = "dps", name = "Arms Leveling (31/20/0)", order = {
      "Improved Heroic Strike:3","Deflection:2","Tactical Mastery:5","Anger Management:1","Deep Wounds:3",
      "Improved Overpower:2","Two-Handed Weapon Specialization:5","Impale:2","Sweeping Strikes:1",
      "Sword Specialization:5","Improved Hamstring:1","Mortal Strike:1",
      "Cruelty:5","Unbridled Wrath:5","Piercing Howl:1","Blood Craze:3","Improved Cleave:1","Enrage:5" } },
    { role = "tank", name = "Protection Tank (20/0/31)", order = {
      "Shield Specialization:5","Toughness:5","Defiance:5","Improved Shield Block:3","Last Stand:1",
      "Improved Sunder Armor:1","Concussion Blow:1","Improved Revenge:3","Anticipation:1",
      "One-Handed Weapon Specialization:5","Shield Slam:1",
      "Improved Heroic Strike:3","Tactical Mastery:5","Deflection:2","Anger Management:1","Deep Wounds:3",
      "Improved Overpower:1","Improved Rend:3","Improved Thunder Clap:2" } },
  },
  MAGE = {
    { role = "dps", name = "Frost Leveling (20/0/31)", order = {
      "Improved Frostbolt:5","Ice Shards:5","Piercing Ice:3","Cold Snap:1","Improved Blizzard:1",
      "Frost Channeling:3","Shatter:2","Ice Block:1","Improved Cone of Cold:3","Shatter:3",
      "Elemental Precision:3","Ice Barrier:1",
      "Arcane Subtlety:2","Arcane Focus:3","Arcane Concentration:5","Improved Arcane Explosion:3",
      "Wand Specialization:2","Arcane Meditation:3","Arcane Focus:2" } },
  },
  ROGUE = {
    { role = "dps", name = "Combat Swords (20/31/0)", order = {
      "Improved Sinister Strike:2","Lightning Reflexes:3","Precision:5","Endurance:2","Riposte:1","Improved Gouge:2",
      "Dual Wield Specialization:5","Lightning Reflexes:2","Blade Flurry:1","Sword Specialization:5",
      "Weapon Expertise:2","Adrenaline Rush:1",
      "Improved Eviscerate:3","Malice:5","Ruthlessness:3","Murder:2","Relentless Strikes:1","Lethality:5","Remorseless Attacks:1" } },
  },
  HUNTER = {
    { role = "dps", name = "Beast Mastery Leveling (31/20/0)", order = {
      "Improved Aspect of the Hawk:5","Endurance Training:5","Unleashed Fury:5","Ferocity:5",
      "Bestial Swiftness:1","Intimidation:1","Bestial Discipline:2","Spirit Bond:1","Frenzy:5","Bestial Wrath:1",
      "Efficiency:5","Lethal Shots:5","Aimed Shot:1","Hawk Eye:3","Improved Arcane Shot:1","Mortal Shots:5" } },
  },
  WARLOCK = {
    { role = "dps", name = "Affliction Leveling (31/20/0)", order = {
      "Improved Corruption:5","Improved Life Tap:2","Improved Drain Life:3","Improved Curse of Agony:3",
      "Fel Concentration:2","Nightfall:2","Grim Reach:2","Fel Concentration:1","Siphon Life:1",
      "Improved Drain Life:2","Fel Concentration:2","Shadow Mastery:5","Dark Pact:1",
      "Demonic Embrace:5","Improved Voidwalker:3","Improved Imp:2","Fel Stamina:5","Fel Domination:1","Unholy Power:4" } },
  },
  PRIEST = {
    { role = "dps", name = "Shadow Leveling (20/0/31)", order = {
      "Spirit Tap:5","Improved Shadow Word: Pain:2","Shadow Focus:3","Mind Flay:1","Improved Mind Blast:4",
      "Shadow Weaving:5","Vampiric Embrace:1","Improved Vampiric Embrace:2","Improved Mind Blast:1",
      "Shadow Focus:1","Darkness:5","Shadowform:1",
      "Wand Specialization:5","Improved Power Word: Shield:3","Martyrdom:2","Meditation:3","Inner Focus:1",
      "Silent Resolve:1","Mental Agility:5" } },
    { role = "heal", name = "Holy Healer (21/30/0)", order = {
      "Healing Focus:2","Improved Renew:3","Divine Fury:5","Inspiration:3","Holy Nova:1","Blessed Recovery:1",
      "Improved Healing:3","Holy Reach:2","Spiritual Guidance:5","Spiritual Healing:5",
      "Wand Specialization:5","Improved Power Word: Shield:3","Martyrdom:2","Meditation:3","Inner Focus:1",
      "Silent Resolve:1","Mental Agility:5","Divine Spirit:1" } },
  },
  PALADIN = {
    -- WoW Forever Paladin trees (from /tsc debug, Nov 2026)
    { role = "dps", name = "Retribution (12/8/31)", order = {
      "Benediction:5","Conviction:3","Improved Judgement:2","Seal of Command:1","Pursuit of Justice:2",
      "Vindication:2","Sacred Arbiter:1","Two-Handed Weapon Specialization:3","Eye for an Eye:1",
      "Vengeance:3","Repentance:1","Sanctified Judgement:1","Champion of the Light:5","Unsealed Wrath:1",
      "Divine Intellect:5","Precision:3",
      "Divine Strength:5","Improved Seals:5","Holy Conduit:2" } },
    { role = "heal", name = "Holy Healer (31/11/9)", order = {
      "Spiritual Focus:5","Healing Light:3","Reverence:2","Illumination:5","Divine Favor:1",
      "Infusion of Light:2","Oath of Light:1","Purifying Power:2","Holy Shock:1","Boundless Light:2",
      "Holy Conduit:1","Holy Power:5","Light's Vigil:1",
      "Divine Intellect:5","Sacred Duty:2","Guardian's Favor:2","Precision:1","Templar's Bulwark:1",
      "Benediction:5","Sanctified Judgement:3","Conviction:1" } },
    { role = "tank", name = "Protection Tank (10/31/10)", order = {
      "Redoubt:5","Precision:3","Sacred Duty:2","Toughness:5","Improved Righteous Fury:3","Anticipation:2",
      "Holy Shield:1","Shield Specialization:2","Templar's Bulwark:1","Reckoning:1","Iron Creed:3",
      "Anticipation:2","Shieldsworn:1",
      "Divine Strength:5","Improved Seals:5",
      "Benediction:5","Improved Judgement:2","Conviction:3" } },
  },
  SHAMAN = {
    { role = "dps", name = "Enhancement Leveling (20/31/0)", order = {
      "Ancestral Knowledge:5","Thundering Strikes:5","Two-Handed Axes and Maces:1","Improved Ghost Wolf:2",
      "Enhancing Totems:2","Flurry:5","Elemental Weapons:3","Parry:1","Improved Weapon Totems:1",
      "Weapon Mastery:5","Stormstrike:1",
      "Concussion:5","Convection:5","Elemental Focus:1","Call of Thunder:5","Elemental Devastation:3","Reverberation:1" } },
    { role = "heal", name = "Restoration Healer (0/20/31)", order = {
      "Improved Healing Wave:5","Tidal Focus:5","Nature's Guidance:3","Healing Focus:2","Tidal Mastery:5",
      "Nature's Swiftness:1","Healing Way:3","Healing Focus:1","Purification:5","Mana Tide Totem:1",
      "Ancestral Knowledge:5","Thundering Strikes:5","Improved Ghost Wolf:2","Two-Handed Axes and Maces:1",
      "Enhancing Totems:2","Flurry:5" } },
  },
  DRUID = {
    { role = "dps", name = "Feral Leveling (0/31/20)", order = {
      "Ferocity:5","Feral Instinct:3","Brutal Impact:2","Sharpened Claws:3","Feline Swiftness:2",
      "Predatory Strikes:3","Blood Frenzy:2","Faerie Fire (Feral):1","Savage Fury:2","Primal Fury:2",
      "Heart of the Wild:5","Leader of the Pack:1",
      "Furor:5","Improved Mark of the Wild:5","Improved Enrage:2","Reflection:3","Nature's Focus:5" } },
    { role = "tank", name = "Bear Tank (0/31/20)", order = {
      "Ferocity:5","Thick Hide:5","Sharpened Claws:3","Feral Charge:1","Feline Swiftness:1",
      "Predatory Strikes:3","Primal Fury:2","Faerie Fire (Feral):1","Savage Fury:2","Feral Instinct:2",
      "Heart of the Wild:5","Leader of the Pack:1",
      "Furor:5","Improved Mark of the Wild:5","Improved Enrage:2","Reflection:3","Nature's Focus:5" } },
    { role = "heal", name = "Restoration Healer (0/20/31)", order = {
      "Furor:5","Improved Healing Touch:5","Reflection:3","Insect Swarm:1","Nature's Focus:1",
      "Improved Rejuvenation:3","Tranquil Spirit:2","Nature's Swiftness:1","Gift of Nature:4",
      "Improved Regrowth:5","Swiftmend:1",
      "Ferocity:5","Thick Hide:5","Sharpened Claws:3","Feline Swiftness:2","Predatory Strikes:3","Blood Frenzy:2" } },
  },
}
