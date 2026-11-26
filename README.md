# Azeroth Survivors Telegraphs

Ground telegraphs for **Azeroth Survivors**: the areas your spells and their effects hit, drawn on the floor around your hero. Each class gets the telegraphs that fit its spells, and every class gets the ones for shared amulets and co-op revives.

## Install

1. Download **AzerothSurvivorsTelegraphs-*version*.zip** from the [latest release](https://github.com/zac-omar/AzerothSurvivorsTelegraphs/releases/latest).
2. Unzip it into your game's `benilla-config\AddOns\` folder. It holds the `AzerothSurvivorsTelegraphs` folder, ready to go. You should end up with:
   ```
   <game folder>\benilla-config\AddOns\AzerothSurvivorsTelegraphs\AzerothSurvivorsTelegraphs.toc
   ```
3. Start the game. If the addon isn't loaded, enable it on the AddOns screen at character select.

To update, delete the old `AzerothSurvivorsTelegraphs` folder and unzip the new release in its place (your settings are kept). Using **Code → Download ZIP** instead? That unpacks as `AzerothSurvivorsTelegraphs-main`: rename the folder to `AzerothSurvivorsTelegraphs`.

Click the **minimap button** or type **`/ast`** to open the options.

If you also run Priest Telegraphs, this addon leaves the telegraphs that both addons draw to Priest Telegraphs. Turn one of the two off at the AddOns screen.

## Telegraphs

"Read from its tooltip" means the size comes live from the spell's tooltip on your action bar, so every bonus counts. A telegraph marked *(experimental)* is off by default (see [Ground telegraphs](#ground-telegraphs)).

### Warrior

| Telegraph | When it shows | Size |
|---|---|---|
| **Whirlwind** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Thunder Clap** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Demoralizing Shout** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Cleave** | Briefly on each cast: how far it reaches (up to 3 enemies within it are struck) | Read from its tooltip |
| **Bloodrage** | With Bloodrage: flashes when you erupt at 100 rage | Read from its tooltip (9 yd × your Area, more with its Charm of the Fated Hour) |
| **Rampage** | With Rampage: flashes when a 7th kill unleashes a free Whirlwind | Your Whirlwind's size |
| **Bladestorm** | With Bladestorm: flashes with each free Whirlwind (every 3 sec) | Your Whirlwind's size |
| **Shockwave** | With Shockwave: around the first target of each Shield Slam | 8 yd |
| **Reaper's Amulet: Execute** | With The Reaper's Amulet on Execute: around each Execute hit's target | 6 yd |
| **Pendant of the Plague** | With it on Rend: where an enemy dies with your Rend on it | 7 yd |
| **Strike reach** | Always (off by default) | How far your strikes reach, from their tooltips |
| **Melee range** | Always (off by default) | How far your melee swings reach for an enemy: 6 yd, centre to centre |

### Paladin

| Telegraph | When it shows | Size |
|---|---|---|
| **Holy Wrath** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Consecration** | On the ground where you stood when it went down, for as long as it lasts (with the Uncommon armor set's 8 pieces: a ring locked around you, see [Armor sets](#armor-sets)) | Read from its tooltip |
| **Free Consecration** *(experimental)* | With Hallowed Ground or Divine Intervention: where their free Consecration burns | Read from Consecration's tooltip |
| **Redemption** | With Redemption: on the body of an enemy that bursts in holy light | Read from its tooltip (8 yd × your Area, more with its Charm of the Fated Hour) |
| **Light's Grace** | With Light's Grace: fills toward the free Holy Wrath every 14 sec (or just flashes when it does) | Your Holy Wrath's size |
| **Daybreak** | With Daybreak: flashes when a Holy Shock crit calls down a free Holy Wrath | Your Holy Wrath's size |
| **Divine Storm** | With Divine Storm: around each Exorcism's target | 5 yd |
| **Inferno: Consecration kills** | With the Amulet of the Inferno on Consecration: where an enemy it kills explodes | 7 yd |
| **Epic set: Judgement kills** | With the Epic armor set's 8 pieces: where an enemy Judgement kills explodes | 8 yd |
| **T0.5 set: Hammer of Justice** | With the T0.5 armor set's 8 pieces: around each Hammer of Justice's target | 10 yd |
| **Spell range** | Always (off by default) | How far your targeted spells look for enemies, from their tooltips |
| **Melee range** | Always (off by default) | How far your melee swings reach for an enemy: 6 yd, centre to centre |

### Hunter

| Telegraph | When it shows | Size |
|---|---|---|
| **Volley** *(experimental)* | On the ground where it lands, for as long as it lasts | Read from its tooltip |
| **Immolation Trap** | On the ground where you set it, for as long as it burns | Read from its tooltip |
| **Frost Trap** | On the ground where you set it, for as long as it lasts | Read from its tooltip |
| **Free Immolation Traps** *(experimental)* | With Wyvern Sting (every 5 sec) or Counterattack (when an enemy strikes you): the Immolation Trap set at your feet | Read from Immolation Trap's tooltip |
| **Hunter's Mark** | With Hunter's Mark: on the body of the marked enemy when the mark explodes | Read from its tooltip (8 yd × your Area, more with its Charm of the Fated Hour) |
| **Explosive Ammunition** | With Explosive Ammunition: where an enemy your Auto Shot or Multi-Shot kills explodes | 6 yd |
| **Pendant of the Plague** | With it on Serpent Sting: where an enemy dies with your Serpent Sting on it | 7 yd |
| **Inferno: Volley / Immolation Trap / Frost Trap kills** | With the Amulet of the Inferno on that spell: where an enemy it kills explodes | 7 yd |
| **Shot range** | Always (off by default) | How far your shots reach, from their tooltips |

### Rogue

| Telegraph | When it shows | Size |
|---|---|---|
| **Blade Flurry** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Preparation** | With Preparation: fills toward the free Gouge every 6 sec (or just flashes when it does) | Gouge's reach, from its tooltip (8 yd) |
| **Shadow Dance** | With Shadow Dance: around each Backstab's or Eviscerate's target | 5 yd |
| **Toxic Bloom** | With Toxic Bloom: where an enemy dying with your Rupture on it bursts | 7 yd |
| **Pendant of the Plague** | With it on Rupture: where an enemy dies with your Rupture on it | 7 yd |
| **Uncommon set: Rupture bursts** | With the Uncommon armor set's 8 pieces: where an enemy dying with your Rupture on it bursts | 8 yd |
| **Reaper's Amulet: Eviscerate / Backstab** | With The Reaper's Amulet on that strike: around each hit's target | 6 yd |
| **Strike reach** | Always (off by default) | How far your strikes reach, from their tooltips |
| **Melee range** | Always (off by default) | How far your melee swings reach for an enemy: 8 yd, centre to centre |

### Priest

| Telegraph | When it shows | Size |
|---|---|---|
| **Mind Flay** | Always, filling with its cooldown, or briefly on each cast | Read live from your spell's tooltip, so every bonus is included; 120° wide |
| **Holy Nova** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Chastise** | With the Chastise talent: flashes when a Smite crit sets off a free Holy Nova | Your Holy Nova's size |
| **Radiance** | With the Radiance talent: fills toward the free Holy Nova that bursts from you every 24 sec (or just flashes when it does) | Your Holy Nova's size |
| **Psychic Scream** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Shield burst** | Flashes when your Power Word: Shield breaks and bursts, with Divine Aegis (10 yd), The Eternal Talisman on Power Word: Shield (10 yd) or the Uncommon armor set's 8 pieces (8 yd) | Fixed |
| **Spell range** | Always (off by default) | How far your targeted spells look for enemies, from their tooltips |
| **Pendant of the Plague** | Where an enemy dies with your Shadow Word: Pain (or Devouring Plague) on it, while you wear it | 7 yd |
| **Shadowform burst** | Where an enemy dies with your Shadow Word: Pain on it, with the Shadowform capstone | 6 yd |
| **Lightwell** | On the ground around the Lightwell, where you stood when it rose, for as long as it stands (off by default) | How far it strikes, from its tooltip |

### Shaman

| Telegraph | When it shows | Size |
|---|---|---|
| **Fire Nova** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Magma Totem** | On the ground around the totem, beside you where you dropped it, for as long as it stands | Read from its tooltip |
| **Searing Totem** | On the ground around the totem, beside you where you dropped it, for as long as it stands (off by default) | How far it shoots, from its tooltip |
| **Flametongue Weapon** | With Flametongue Weapon: flashes when Rockbiter sets off a free Fire Nova | Your Fire Nova's size |
| **Emberwake Pendant** | While you wear it: around each Flame Shock tick's target | 6 yd |
| **Heart of the Earthbreaker** | While you wear it: around the first target of each Rockbiter Weapon | 6 yd |
| **Uncommon set: Flame Shock kills** | With the Uncommon armor set's 8 pieces: where an enemy dying with your Flame Shock on it explodes | 8 yd |
| **T0.5 set: Thunderburst** | With the T0.5 armor set's 8 pieces: around each Stormstrike's target | 6 yd (8 yd with all eight at 5 stars) |
| **Spell range** | Always (off by default) | How far your targeted spells look for enemies, from their tooltips |

### Mage

| Telegraph | When it shows | Size |
|---|---|---|
| **Frost Nova** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Arcane Explosion** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Blast Wave** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Cone of Cold** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip; 120° wide |
| **Blizzard** *(experimental)* | On the ground where it lands, for as long as it lasts, filling in from its centre | Read from its tooltip, then made exact from what it hits |
| **Flamestrike** *(experimental)* | On the ground where it lands, for as long as it burns, filling in from its centre | Read from its tooltip, then made exact from what it hits |
| **Polymorph** | With Polymorph: where a sheep pops, its arcane burst | Read from its tooltip (more with its Charm of the Fated Hour) |
| **Spell range** | Always (off by default) | How far your targeted spells look for enemies, from their tooltips |
| **Clearcasting explosion** | With Arcane Concentration: flashes when a spell sets off a free Arcane Explosion | Your Arcane Explosion's size |
| **Water Elemental nova** | With Summon Water Elemental: fills toward the free Frost Nova that bursts from you every 8 sec (or just flashes when it does) | Your Frost Nova's size |
| **Pyroclasm** | With the Pyroclasm capstone: where an enemy your Fire spells kill explodes | 6 yd |
| **Splitting Ice** | With Splitting Ice: where each Frostbolt lands and splinters | 5 yd |
| **Inferno: Blizzard / Flamestrike kills** | With the Amulet of the Inferno on Blizzard or Flamestrike: where an enemy it kills explodes | 7 yd |
| **Ice Barrier burst** | With The Eternal Talisman on Ice Barrier: flashes when your Ice Barrier breaks and bursts | 10 yd |

### Warlock

| Telegraph | When it shows | Size |
|---|---|---|
| **Hellfire** | Briefly with each pulse (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Rain of Fire** *(experimental)* | On the ground where it lands, for as long as it lasts | Read from its tooltip |
| **Rain of Chaos** *(experimental)* | With Rain of Chaos: where its free Rain of Fire lands (every 13 sec), shown with its first tick | Read from Rain of Fire's tooltip |
| **Conflagrate** | With Conflagrate: where a Shadow Bolt or Searing Pain makes an enemy burning with your Immolate explode | 6 yd |
| **Seed of Corruption** | With Seed of Corruption: where an enemy dying with your damage over time on it bursts | 6 yd |
| **Pendant of the Plague** | With it on Corruption, Curse of Agony, Drain Life or Immolate: where an enemy dies with it on them | 7 yd |
| **Inferno: Rain of Fire kills** | With the Amulet of the Inferno on Rain of Fire: where an enemy it kills explodes | 7 yd |
| **Spell range** | Always (off by default) | How far your targeted spells look for enemies, from their tooltips |

### Druid

| Telegraph | When it shows | Size |
|---|---|---|
| **Swipe** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Hurricane** *(experimental)* | On the ground where it lands, for as long as it lasts | Read from its tooltip |
| **Tranquility** | With Tranquility: flashes when a heal of yours strikes the enemies around you | 12 yd |
| **Dire Bear Swipe** | In Dire Bear Form: flashes with each free Swipe (every 3 sec) | Your Swipe's size |
| **Enrage** | With Enrage: flashes when an enemy's blow sets off a free Swipe | Your Swipe's size |
| **Pendant of the Plague** | With it on Moonfire or Insect Swarm: where an enemy dies with it on them | 7 yd |
| **Inferno: Hurricane kills** | With the Amulet of the Inferno on Hurricane: where an enemy it kills explodes | 7 yd |
| **Epic set: Starfire bursts** | With the Epic armor set's 8 pieces: around each Starfire's target | 6 yd |
| **Spell range** | Always (off by default) | How far your targeted spells look for enemies, from their tooltips |

### Ground telegraphs

Spells that cover a spot of the ground for a while get a ring there that fills in until the spell ends.

- **Set at your feet when you cast it** (Consecration, Immolation Trap, Frost Trap, Magma Totem; Searing Totem and Lightwell, off by default): the ring goes where you stood when your spell bar showed the cast (the totems 1.5 yd ahead of you, where they stand), and stays there. The first four are on by default.
- **Lands on a group** *(experimental)* (Blizzard, Flamestrike, Volley, Rain of Fire, Hurricane): it lands on the thickest group of enemies in reach. Of the 24 enemies nearest you within its range, that's the one with the most enemies around it. The ring appears as soon as your spell bar shows the cast, placed from where the enemies stood when the spell went off, and it stays there. Which enemy wins depends on the spell's exact size, and the tooltip rounds it (to the yard from 10 yd up). So the addon works it out from which enemies each one hits and which it just misses, and uses that for the casts after. The first cast or two of a run, or after the spell gets bigger, can land a little off.
- **Free ones** *(experimental)* (Rain of Chaos, Hallowed Ground's Consecration, Wyvern Sting's and Counterattack's traps): your spell bar doesn't show these, so each is placed by its first tick, a quarter second after it went down. Your own casts of the same spell hit exactly like the free ones, so a free one shows only while its spell's own telegraph (Rain of Fire, Consecration, Immolation Trap) is on too: that's how it tells your casts' ticks from the free ones'.

Every ring lasts exactly as long as its spell: the tooltip's duration, made exact (the tooltip rounds to the second from 10 sec up), with every bonus, plus the moment the last tick still lands. If a tick ever lands later, the ring runs on with it.

### Every other skill

Every skill without a telegraph above has one of its own too, under **Ranges** on its class's page. They're all off by default:

- **Range** (the skills that strike, afflict or fire at enemies): how far the skill reaches for an enemy, read from its tooltip. It shows always, filling in with the skill's cooldown, or briefly on each cast. Your Area doesn't widen a reach.
- **Trigger** (the buffs cast "once enemies are within 30 yd"): how near enemies must come before the buff goes off.
- **A flash round you** (the heals and shields with no reach): a small ring that flashes on each cast.

| Class | Range | Trigger | Flash |
|---|---|---|---|
| Warrior | Mortal Strike, Execute, Bloodthirst, Rend, Shield Slam | Battle Shout | |
| Paladin | Exorcism, Hammer of Wrath, Holy Shock, Judgement, Hammer of Justice | Holy Shield | Holy Light, Divine Shield |
| Hunter | Auto Shot, Arcane Shot, Multi-Shot, Serpent Sting, Concussive Shot, Aimed Shot | | |
| Rogue | Sinister Strike, Eviscerate, Rupture, Kidney Shot, Gouge, Ghostly Strike, Backstab, Seal Fate | Adrenaline Rush, Slice and Dice | |
| Priest | Smite, Shadow Word: Pain, Mind Blast, Holy Fire, Devouring Plague | | Renew, Power Word: Shield |
| Shaman | Lightning Bolt, Chain Lightning, Earth Shock, Flame Shock, Frost Shock, Stormstrike, Rockbiter Weapon | Lightning Shield | Healing Wave |
| Mage | Fireball, Frostbolt, Arcane Missiles, Fire Blast, Pyroblast | | Ice Barrier |
| Warlock | Shadow Bolt, Corruption, Immolate, Curse of Agony, Death Coil, Searing Pain, Drain Life, Fear, Soulfire | Demonic Empowerment | |
| Druid | Wrath, Moonfire, Starfire, Insect Swarm, Entangling Roots, Faerie Fire, Shred | Thorns | Rejuvenation, Regrowth |

Seal Fate, Soulfire and Faerie Fire also show once the damage meter lists them in your loadout: as a plain ring if your spell bar has no cooldown for them.

### Armor sets

An armor set's 8-piece bonus (all eight pieces of one set at 3 stars or more) is known from the armor you wear: the addon checks your eight armor pieces, and each piece's stars from its tooltip ("Upgraded: 4/5 stars"). With all eight at 5 stars the bonus is empowered. T0.5 sets are known from their own hits instead, as the game credits them to the set, and so is any set whose pieces' stars can't be read.

The explosions (Judgement, Rupture, Flame Shock) show on the body as they go off. Starfire's bursts and the Power Word: Shield explosion show from the first one when your armor shows the set. The T0.5 bonuses (Hammer of Justice, Thunderburst) show from their second one on, once the first has shown you have the set. Bonuses that make a spell wider or longer are in its tooltip, so its telegraph already has them.

With the 8-piece bonus that makes a ground spell move with you (Consecration with the Uncommon paladin set, Volley with the Epic hunter set, Blizzard with the Epic mage set), it becomes a ring locked around you, like your other rings: it fills in from the centre as the spell's time runs, with a shockwave on each cast. A Volley or Blizzard cast on a group comes straight to you. When each one lasts as long as the spell's cooldown or longer, so the next always arrives before it ends, the ring stays full and gently breathes, and two small comets of light circle its edge to show it's up for good. If the next one is late (Consecration waits for enemies to come near), the fill comes back so you can see the time running out.

Not shown: the T0.5 sets' 4-piece bonuses that change a size (Splitting Ice 7 yd, Conflagrate 8 yd, Tranquility 15 yd), since they have no hits of their own to tell them by, and the druid T0.5 Seed of Life.

### Any class

| Telegraph | When it shows | Size |
|---|---|---|
| **Choker of the Fire Lord** | Where an enemy you kill explodes, while you wear it | 6 yd |
| **Onyxia Tooth Pendant** | Where your critical hits splash, while you wear it | From the amulet's text (5 yd, more when empowered) |
| **War Stomp** | Tauren: flashes when War Stomp goes off, stunning everything inside for 2 sec (or fills toward the next one) | Its tooltip (8 yd at base, grows with your Area) |
| **Escape Artist** | Gnome: flashes when Escape Artist goes off, rooting everything inside for 2 sec (or fills toward the next one) | Its tooltip (8 yd at base, grows with your Area) |
| **Revive range** | In co-op, around each downed teammate; fills as you bring them back. Stand inside it to revive (6 sec, 9 at Heroic 5+; faster with more friends) | 5 yd |
| **Custom ring** | A ring of any size around you (off by default; `/ast ring 10` sets it to 10 yd) | Your setting |
| **Custom ring 2, 3, ...** | As many more as you like: **Add a ring** under the list. Any class rings show for every hero; a class page has its own, shown while you play that class | Your setting |
| **Guardian wake range** | Around each guardian asleep at its lair: come this near (or hit it) and it wakes. It warms to red as you close in | 20 yd |
| **Guardian leash** | Around the lair of a guardian that's chasing you: past this ring it gives up, walks home and heals to full. It warms to red as you near it, with a line under your hero ("gives up in 8 yd") | 97.5 yd from its lair |
| **Minimap pins** | On the minimap: guardians (white asleep, red when chasing you), empty lairs with the time until they fill, bosses and caches. Ones past the minimap's edge wait on its rim. While you play, the game's own red flag on the nearest guardian is hidden (it comes back when you leave the game, so removing the addon leaves your game as it was; with Survivor UI or SurvivorsDragonUi the flag is left to their own setting) | |
| **Minimap range ring** | On the minimap, round you: how far your chosen skill reaches. It lights up when a guardian's lair is within it, so you can strike the guardian the moment it appears | your skill's range |

Guardians: one asleep at its lair wakes when it's hit, or when a hero comes within 20 yd of it. Once awake it follows you while you're within 97.5 yd of its lair (not of the guardian). Go past that and it gives up, walks home and heals back to full health. Hit it on the way and it turns around. On its way home, coming near doesn't wake it; only a hit does. In a party it first turns to another hero still within reach of its lair.

The **minimap range ring** has a skill picker for every class in one place, so each of your heroes keeps its own (each class starts on its spell range, shot range or strike reach). Pick **Longest** and it follows whichever of your skills reaches furthest right now, switching as soon as another one grows past it. You can also type a range of your own instead. You choose what lights it: empty lairs (any time, or only those filling within so many seconds), sleeping guardians, guardians chasing you, and bosses. An early warning can colour it a few yards before. It can be solid or dotted, with its own width, colours and opacity, a fill, a pulse while in range, a ring round whatever is in range, the range written over it, or stay hidden until a lair is near.

Telegraphs stand still while the game does: while you choose an upgrade or a chest's prize, and on the pause screen. Nothing fills or runs out meanwhile, and they carry on when you're back. A **Test** press still plays.

Telegraphs for abilities, items and talents only appear while your hero has them, and a racial's only for its race. Abilities, talents and run jewelry come from the damage meter's list of your loadout; amulets are also read from their tooltips as you swap them during a run. The amulets' "at most N times a second" limits, sizes and "+N% area" / "+N% duration" are read from their own text.

Your talents come from the damage meter, which lists each one with its rank. If the meter hasn't got them yet, the addon asks it again every 5 seconds (`/ast meter` shows what it has, `/ast meter off` stops the asking). Until then, a talent with an aura (Shadowform) is recognised from the aura, and the others the first time they go off.

## Hero bar

A health bar of your own, off to start with: turn it on in the options under **Bars**, on its **Hero bar** tab. It has tabs of its own: Bar (with the game frames it can hide), Health & mana, Shields and Icons.

- **Where it goes:** wherever you drag it (unlock it first), above your hero or under your hero, at any scale. Three looks to start from: Subdued, Sleek and Bold.
- **Health:** coloured by health, by class or in your own colour, with a damage trail, a low-health warning and the numbers in any of several forms. Mana (or rage, or energy) can sit underneath, and your level in the run beside it.
- **Shields:** laid over your health. Past 100% a second layer goes over the first, and a third past 200%, each in its own colour. Or show just a fixed mark at the bar's end while you have any shield. The shield can also be added into the health numbers.
- **Icons:** your skills from action bars 1 to 6, the jewelry you wear and your buffs, under or over the bar, with their cooldowns if you want them. Pick exactly which ones show: each class's skills on their own, and one list each for jewelry and buffs.
- **Game frames:** hide the game's own player frame, your skill and jewelry icons under it, or the buff and debuff icons by the minimap (the enemy's frame: on the target bar's page). Where another addon is handling one of these (Survivor UI's Unit frames, Buffs or Build list), its box says which addon and which of its settings, and can't be changed until that addon stops handling it (your choice is kept).
- **Test** plays a short demo, even with the bar turned off. `/ast bar` shows or hides it (`/ast bar lock`, `unlock`, `test`, `reset`).

## Target bar

The enemy you target on a bar like the hero bar, off to start with: turn it on in the options under **Bars**, on its **Target bar** tab. It has tabs of its own: Bar, Health & mana, Name & numbers, and Debuffs & buffs.

- **Where it goes:** wherever you drag it (unlock it first), or beside the hero bar on any side, at any scale. The hero bar's three looks: Subdued, Sleek and Bold.
- **Health:** its real numbers where the game gives them, else its share. Coloured by what it is (enemies, elites, guardians, bosses and friends each in a colour you choose), by health, or in your own colour, with a damage trail. An **execute range** marks a share of its health and lights the bar once it's below it. Its mana can sit underneath.
- **Name and numbers:** its name above, inside or under the bar, with Elite, Guardian or Boss after it, whom it's after, its level (before its name or beside the bar), and the numbers in any of the hero bar's forms.
- **Debuffs and buffs:** each in its own rows, above or under the bar, with how many, their size and how they line up. Their stacks, the seconds left and a shade over the time gone (where the game tells it: a guardian's and a boss's), an edge coloured by what takes a debuff off, and tooltips if you want them.
- **The game's enemy frame** can be hidden from its page too, for the target bar to take its place.
- **Test** plays a short demo, even with it turned off. `/ast target` shows or hides it (`/ast target lock`, `unlock`, `test`, `reset`).

## Languages

The addon follows the game's own language setting (**Options > Language** in the game): English, Polski, Čeština, Deutsch, Português (Brasil), Español, Français, Română, Türkçe, Русский, Українська, 简体中文, 日本語 and 한국어. Change it in the game and the addon changes with it, the options window too, without a `/reload`.

- Spell, talent, amulet and class names are the game's own, exactly as it shows them in that language.
- Sizes, durations and amulet numbers are read from the game's tooltips and item texts in that language, so every telegraph works the same in all of them.
- The addon's own texts (the options window, the telegraphs' descriptions, its chat messages) are translated. Anything not translated shows in English.

## Options

The options window has a tab for each page down its left side:

- **General**: the minimap button, reading your talents from the meter, cone direction, and the commands.
- **All telegraphs**: change many telegraphs at once (see [All telegraphs](#all-telegraphs) below).
- **One tab per class**, yours first and marked "you". The window always opens on yours. You can set up another class's telegraphs before you play it.
- **Any class**, below the classes: the telegraphs any hero can use (amulets, racials, co-op revives, the custom ring).

**Add a ring** at the bottom of a page's list makes a new ring of your own on that page, each in its own colour, as many as you like: for example a few static rings of different sizes around you. Rings on Any class show for every hero; rings on a class page show while you play that class. Set each one's **Radius** (type it in if you like) and colours, and **Remove ring** takes it away again.

A class page lists its telegraphs under **Spells**, **Talents**, **Amulets** and **Sets** (armor set bonuses), and the experimental ones (off by default) under **Experimental**. The Any class page has **Amulets**, **Racial** and **Other**. The dot beside each one turns it on or off, and its colour says where it stands:

- **Green**: on, and your hero has it now (the spell this run, the talent, the amulet or the set).
- **Amber**: on, but waiting: your hero doesn't have it right now, or (a free one) its spell's own telegraph is off, so it isn't drawn. Point at the dot to see what it needs.
- **Red**: off.

Click a telegraph to see what it shows, its size right now, whether your hero has it, and its settings (scroll for more):

- **Behaviour**
  - **When**: briefly on cast, or always with a cooldown fill (or when it goes off).
  - **Flash length**, and **Most at once** for every telegraph that can show more than one: the newest rings when a pack dies together, the newest spots of a ground spell, the nearest guardians and downed teammates.
  - **Cooldown fill**, **Duration fill** and **Uptime look**: untick one to drop that time from the telegraph.
- **Parts**: each part of the telegraph on or off, and off means gone entirely (no need to set an opacity to 0):
  - **Outline**: the ring's (or cone's) edge.
  - **Glow**: the soft light along the edge.
  - **Fill**: the area itself, and what fills it in.
  - **Background area**: the faint area still to fill, behind a cooldown or duration fill.
  - **Front line**: the bright line the fill has reached.
  - **Cast pulse**: the flash and shockwave of each cast.
- **Size**: **Size override** (or **Radius**, for your own rings): step it with - and +, or click the number and type any size up to 100 yd, such as 27.5. A size override of 0 goes back to the automatic size.
- **Look**
  - **Style**: *Texture* (rings from the game's own fine ring texture: smooth, glowing and sharp at any size, the standard look), *Drawn* (drawn from pieces) or *Dots*, each with its own options.
  - **Colours, opacity and width** for the outline and the fill, with presets or a colour picker.
- **Test** shows the telegraph for 3 seconds. **Reset** puts that telegraph back as it came. **Copy look to...** gives this telegraph's style, colours, sizes and parts to every telegraph on this page, or to every telegraph of every class.

### All telegraphs

The **All telegraphs** tab changes many telegraphs in one click. Each change is written into every telegraph it reaches, so afterwards you can open any one of them and set it differently.

- **Change**: your class and Any class, every class, or only your own rings.
- **Keep my own** (on to start with): leaves alone anything you changed on a telegraph's own page, so your own touches stick when you change everything else. **Forget which ones I set by hand** clears that.
- **Quick changes**: turn every one on or off; set every one to *Briefly on cast*, *Always + cooldown fill* or *When it goes off* (each one that has it); every one's style.
- **Parts**: each part on or off everywhere at once.
- **Numbers**: pick a value, then **Apply**: outline width and opacity, fill opacity, flash length, fill detail, dot size and spacing, size override, ring radius, most at once.
- **Colours**: one outline or fill colour for every one, or back to each one's own colours.
- **Start over**: reset the telegraphs it reaches to their defaults (it asks first).

**Reset everything to defaults**, at the bottom of the **General** tab, puts every telegraph on every page and the General settings back as they came. It asks first, in case of a misclick. Your own rings stay (their settings are reset too), and so do where the window and the minimap button sit.

Telegraphs start out as just their ring: a thin outline, with no fill, no cooldown or duration filling it in, and no glow. The brief flashes (a cast, a proc, an enemy effect) are a little brighter than the rings that are always up (ranges, your own rings). Turn on a telegraph's **Fill**, **Glow**, **Cooldown fill** or **Duration fill** on its page, or for all of them at once on the All telegraphs tab. If you've used an older version, your telegraphs keep the look they had: **Reset everything to defaults** gives you the new one.

**Hide all** (top right of the window, or right-click the minimap button) turns every telegraph off and on again without losing your settings.

**Showcase** (top of the window, or `/ast showcase`) shows everything the addon draws at once, for a video or a screenshot. It is one big telegraph turning round your hero:

- your class's main ring at the centre, filling with its cooldown on a rune circle;
- its cone sweeping round;
- its other telegraphs orbiting one way, and Any class's (amulets, racials, revive, guardians, skill ranges, your own rings) the other;
- your spell range round it all, with two comets circling it.

Each one shows its whole look in its own colours, and its name as it comes round to the front. The minimap pins play too. It sizes itself to fit your screen and runs until you press **Stop showcase** or type the command again. Your telegraphs pause while it runs, and none of your settings change.

If your frame rate drops, lower **Fill detail**, turn off **Glow**, or set **Most at once**.

## Sharing setups

Click **Import / Export** at the top of the options window, or type `/ast share`.

- **Export every class**, or **Export** the page you're on (a class, or Any class), puts your setup in the box as one line of text, already selected. Press **Ctrl+C** and share it.
- To use someone else's line, paste it into the box with **Ctrl+V**. Before anything changes, the box says what the line holds (how many telegraphs, which classes). **Import** applies it.
- A line changes only the telegraphs it holds, each set exactly as the person who exported it had it. So you can take one person's Paladin setup and someone else's Mage setup, or grab one line that sets every class at once.
- Your own rings travel too. A line with a page's rings replaces your rings on that page with them, so importing the same line twice doesn't double them.
- A line from another version of the addon still imports. Telegraphs that version doesn't have are left out, and the box says how many.
- Only the telegraphs' settings are shared: on or off, when they show, size, style and colours. Your window, minimap button and cone direction stay your own.

## Minimap button

It starts in a free spot on the minimap's edge, clear of the other buttons there.

- **Left-click**: open or close the options.
- **Right-click**: hide or show every telegraph.
- **Drag**: move it around the minimap.
- `/ast minimap` hides the button (and brings it back).

## Commands

| Command | What it does |
|---|---|
| `/ast` | Open or close the options |
| `/ast ring <yards>` | Turn on the custom ring at that size (`/ast ring` alone toggles it) |
| `/ast minimap` | Hide or show the minimap button |
| `/ast share` | Open Import / Export, to share telegraph setups |
| `/ast meter` | Show your talents as the damage meter lists them (`/ast meter off` / `on` stops or starts asking it) |
| `/ast debug` | Show what the addon reads: your class, spells, sizes, cooldowns, problems |
| `/ast events` | Show the last combat hit and the items and talents it detected |
| `/ast spotlog` | Start or stop recording where the ground spells land, what they hit, the sizes worked out and how late the spell bar was, to report a ring that's off; `/reload` saves it to the settings file |
| `/ast mirror`, `/ast rotate <degrees>` | Fix a cone that points the wrong way |
| `/ast showcase` | Start or stop the showcase (see below) |

## Adding a class

Each class's telegraphs are in a file of their own (`ClassPriest.lua`), and the ones every class has are in `ClassCommon.lua`. A class file hands its list to `AST_Register`; the fields are described at the top of `Core.lua`. Add the new file to `AzerothSurvivorsTelegraphs.toc`. The class gets its own tab in the options window automatically, with the icon and description its file gives.

`Core.lua` draws the telegraphs; `Options.lua` is the options window; `Locale.lua` picks the game's language, and `Locales\` holds each language's words. A new text shows in English until it's added there.

## Notes

- **Works alongside Survivor UI and SurvivorsDragonUi.** On their square minimaps the pins, the range ring and the minimap button keep to the square's edge, and they stay over the minimap and fade with it. The hero bar's frame options only ever hide the game's own frames.
- The game's **Enhanced Tooltips** setting is kept on: sizes are read from your skills' tooltips, which show only the skill's name with it off.
- The addon draws through the game's world-anchor API. It needs at least one enemy, cache or lair on the map to place shapes, so telegraphs can be missing for the first moment of a run.
- This is an unofficial fan-made addon.
