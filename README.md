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

### Paladin

| Telegraph | When it shows | Size |
|---|---|---|
| **Holy Wrath** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Consecration** | On the ground where you stood when it went down, for as long as it lasts | Read from its tooltip |
| **Free Consecration** *(experimental)* | With Hallowed Ground or Divine Intervention: where their free Consecration burns | Read from Consecration's tooltip |
| **Redemption** | With Redemption: on the body of an enemy that bursts in holy light | Read from its tooltip (8 yd × your Area, more with its Charm of the Fated Hour) |
| **Light's Grace** | With Light's Grace: fills toward the free Holy Wrath every 14 sec (or just flashes when it does) | Your Holy Wrath's size |
| **Daybreak** | With Daybreak: flashes when a Holy Shock crit calls down a free Holy Wrath | Your Holy Wrath's size |
| **Divine Storm** | With Divine Storm: around each Exorcism's target | 5 yd |
| **Inferno: Consecration kills** | With the Amulet of the Inferno on Consecration: where an enemy it kills explodes | 7 yd |
| **Epic set: Judgement kills** | With the Epic armor set's 8 pieces: where an enemy Judgement kills explodes | 8 yd |
| **T0.5 set: Hammer of Justice** | With the T0.5 armor set's 8 pieces: around each Hammer of Justice's target | 10 yd |
| **Spell range** | Always (off by default) | How far your targeted spells look for enemies, from their tooltips |

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

### Shaman

| Telegraph | When it shows | Size |
|---|---|---|
| **Fire Nova** | Briefly on each cast (or always, filling from the centre with its cooldown) | Read from its tooltip |
| **Magma Totem** | On the ground around the totem, beside you where you dropped it, for as long as it stands | Read from its tooltip |
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

- **Set at your feet when you cast it** (Consecration, Immolation Trap, Frost Trap, Magma Totem): the ring goes where you stood when your spell bar showed the cast (Magma Totem 1.5 yd ahead of you, where the totem stands), and stays there. These are on by default.
- **Lands on a group** *(experimental)* (Blizzard, Flamestrike, Volley, Rain of Fire, Hurricane): it lands on the thickest group of enemies in reach. Of the 24 enemies nearest you within its range, that's the one with the most enemies around it. The ring appears as soon as your spell bar shows the cast, placed from where the enemies stood when the spell went off, and it stays there. Which enemy wins depends on the spell's exact size, and the tooltip rounds it (to the yard from 10 yd up). So the addon works it out from which enemies each one hits and which it just misses, and uses that for the casts after. The first cast or two of a run, or after the spell gets bigger, can land a little off.
- **Free ones** *(experimental)* (Rain of Chaos, Hallowed Ground's Consecration, Wyvern Sting's and Counterattack's traps): your spell bar doesn't show these, so each is placed by its first tick, a quarter second after it went down. Your own casts of the same spell hit exactly like the free ones, so a free one shows only while its spell's own telegraph (Rain of Fire, Consecration, Immolation Trap) is on too: that's how it tells your casts' ticks from the free ones'.

Every ring lasts exactly as long as its spell: the tooltip's duration, made exact (the tooltip rounds to the second from 10 sec up), with every bonus, plus the moment the last tick still lands. If a tick ever lands later, the ring runs on with it.

### Armor sets

An armor set's 8-piece bonus (all eight pieces of one set at 3 stars or more) is known from the armor you wear: the addon checks your eight armor pieces, and each piece's stars from its tooltip ("Upgraded: 4/5 stars"). With all eight at 5 stars the bonus is empowered. T0.5 sets are known from their own hits instead, as the game credits them to the set, and so is any set whose pieces' stars can't be read.

The explosions (Judgement, Rupture, Flame Shock) show on the body as they go off. Starfire's bursts and the Power Word: Shield explosion show from the first one when your armor shows the set. The T0.5 bonuses (Hammer of Justice, Thunderburst) show from their second one on, once the first has shown you have the set. Bonuses that make a spell wider or longer are in its tooltip, so its telegraph already has them.

A ground ring stays where its spell was put, even with the 8-piece bonus that makes Consecration (Uncommon paladin set), Volley (Epic hunter set) or Blizzard (Epic mage set) move with you: that bonus has no hits of its own to tell it by.

Not shown: the T0.5 sets' 4-piece bonuses that change a size (Splitting Ice 7 yd, Conflagrate 8 yd, Tranquility 15 yd), since they have no hits of their own to tell them by, and the druid T0.5 Seed of Life.

### Amulets (every class)

| Telegraph | When it shows | Size |
|---|---|---|
| **Choker of the Fire Lord** | Where an enemy you kill explodes, while you wear it | 6 yd |
| **Onyxia Tooth Pendant** | Where your critical hits splash, while you wear it | From the amulet's text (5 yd, more when empowered) |
| **Revive range** | In co-op, around each downed teammate; fills as you bring them back. Stand inside it to revive (6 sec, 9 at Heroic 5+; faster with more friends) | 5 yd |
| **Custom ring** | A ring of any size around you (off by default; `/ast ring 10` sets it to 10 yd) | Your setting |

Telegraphs stand still while the game does: while you choose an upgrade or a chest's prize, and on the pause screen. Nothing fills or runs out meanwhile, and they carry on when you're back. A **Test** press still plays.

Telegraphs for abilities, items and talents only appear while your hero has them. Abilities, talents and run jewelry come from the damage meter's list of your loadout; amulets are also read from their tooltips as you swap them during a run. The amulets' "at most N times a second" limits, sizes and "+N% area" / "+N% duration" are read from their own text.

Your talents come from the damage meter, which lists each one with its rank. If the meter hasn't got them yet, the addon asks it again every 5 seconds (`/ast meter` shows what it has, `/ast meter off` stops the asking). Until then, a talent with an aura (Shadowform) is recognised from the aura, and the others the first time they go off.

## Languages

The addon follows the game's own language setting (**Options > Language** in the game): English, Polski, Čeština, Deutsch, Português (Brasil), Español, Français, Română, Türkçe, Русский, Українська, 简体中文, 日本語 and 한국어. Change it in the game and the addon changes with it, the options window too, without a `/reload`.

- Spell, talent, amulet and class names are the game's own, exactly as it shows them in that language.
- Sizes, durations and amulet numbers are read from the game's tooltips and item texts in that language, so every telegraph works the same in all of them.
- The addon's own texts (the options window, the telegraphs' descriptions, its chat messages) are translated. Anything not translated shows in English.

## Options

The options window has a tab for each page down its left side:

- **General**: the minimap button, reading your talents from the meter, cone direction, and the commands.
- **One tab per class**, yours first and marked "you". The window always opens on yours. You can set up another class's telegraphs before you play it.
- **Amulets**, below the classes: the telegraphs any hero can use (amulets, co-op revives, the custom ring).

A class page lists its telegraphs under **Spells**, **Talents**, **Amulets** and **Sets** (armor set bonuses), and the experimental ones (off by default) under **Experimental**. The dot beside each one turns it on or off, and its colour says where it stands:

- **Green**: on, and your hero has it now (the spell this run, the talent, the amulet or the set).
- **Amber**: on, but waiting: your hero doesn't have it right now, or (a free one) its spell's own telegraph is off, so it isn't drawn. Point at the dot to see what it needs.
- **Red**: off.

Click a telegraph to see what it shows, its size right now, whether your hero has it, and its settings:

- **When**: briefly on cast, or always with a cooldown fill.
- **Flash length**, and **Most at once** for the enemy effects: a limit on how many rings are drawn when a pack dies together. Off by default; set it if your frame rate drops.
- **Size override**, if you'd rather set a size yourself.
- **Style**: *Smooth* (solid fills and outlines with a glow) or *Dots*, with their own options.
- **Colours and opacity** for the outline and the fill, with presets or a colour picker.
- **Test** shows the telegraph for 3 seconds so you can see your changes. **Reset to defaults** puts that telegraph back as it came.

**Hide all** (top right of the window, or right-click the minimap button) turns every telegraph off and on again without losing your settings.

If your frame rate drops, lower **Fill detail**, turn off **Glow**, or set **Most at once**.

## Sharing setups

Click **Import / Export** at the top of the options window, or type `/ast share`.

- **Export every class**, or **Export** the page you're on (a class, or Amulets), puts your setup in the box as one line of text, already selected. Press **Ctrl+C** and share it.
- To use someone else's line, paste it into the box with **Ctrl+V**. Before anything changes, the box says what the line holds (how many telegraphs, which classes). **Import** applies it.
- A line changes only the telegraphs it holds, each set exactly as the person who exported it had it. So you can take one person's Paladin setup and someone else's Mage setup, or grab one line that sets every class at once.
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

## Adding a class

Each class's telegraphs are in a file of their own (`ClassPriest.lua`), and the ones every class has are in `ClassCommon.lua`. A class file hands its list to `AST_Register`; the fields are described at the top of `Core.lua`. Add the new file to `AzerothSurvivorsTelegraphs.toc`. The class gets its own tab in the options window automatically, with the icon and description its file gives.

`Core.lua` draws the telegraphs; `Options.lua` is the options window; `Locale.lua` picks the game's language, and `Locales\` holds each language's words. A new text shows in English until it's added there.

## Notes

- The addon draws through the game's world-anchor API. It needs at least one enemy, cache or lair on the map to place shapes, so telegraphs can be missing for the first moment of a run.
- This is an unofficial fan-made addon.
