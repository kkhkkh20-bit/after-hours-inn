"""
The Restaurant for Monsters master palette.

One palette for the whole game. Every generator pulls from here, which is what
keeps a dragon, a soup bowl and a menu button looking like they belong on the
same screen. Adding a colour that is not a ramp of one of these families is a
style violation - see CLAUDE.md art rules.

Mood: Stardew Valley warmth - golden-hour wood, vivid grass, rich blues, deep
indigo nights. Deliberately more saturated and higher-contrast than a "cosy
muted" palette; the flat three-tone shading needs the colours themselves to
carry the richness, because there is no gradient doing it for them.
"""

# --- neutrals / structure ---------------------------------------------------
INK = "#2b1d2c"          # darkest, outlines tint toward this
STONE = "#6b6274"
STONE_L = "#9a90a6"
PARCHMENT = "#f0d9a4"
PAPER = "#faeccb"
CHALK = "#fdf6e3"

# --- wood / restaurant ------------------------------------------------------
OAK = "#a86a34"
OAK_DARK = "#6d4020"
OAK_WARM = "#c98a45"
FLOOR_A = "#9c6134"
FLOOR_B = "#8a5530"
WALL_PLASTER = "#e0bd82"
WALL_TRIM = "#95562b"

# --- lamp / fire ------------------------------------------------------------
LAMP = "#ffd166"
LAMP_HOT = "#fff2c4"
EMBER = "#ff9236"
FLAME = "#f85a28"
FLAME_CORE = "#ffd166"
COAL = "#3a2130"

# --- cool / night -----------------------------------------------------------
DUSK = "#33285c"
NIGHT = "#1b1440"
MOON = "#b8d0ff"
SHADOW_TINT = "#1e1730"

# --- nature -----------------------------------------------------------------
LEAF = "#5aa83f"
LEAF_DEEP = "#3a7a2e"
LEAF_LIGHT = "#84c24d"
BARK = "#7d5230"
GRASS = "#63ab3e"
WATER = "#3f86d8"
WATER_DEEP = "#2a5fa8"
MUSHROOM = "#e0503f"
BERRY = "#b03a72"

# --- characters -------------------------------------------------------------
DRAGON_SCALE = "#e04a2b"       # Blaze - proud, hot, generous
DRAGON_BELLY = "#ffbe55"
DRAGON_HORN = "#f2dcae"
DRAGON_WING = "#8f2a24"

VAMP_COAT = "#453070"          # Countess Vex - elegant, exacting
VAMP_SKIN = "#e3d6e8"
VAMP_TRIM = "#9b2c4a"
VAMP_HAIR = "#1d1630"

SLIME_BODY = "#4bd68d"         # Gloop - curious, chaotic
SLIME_CORE = "#a8f0c4"
SLIME_DEEP = "#2f8f63"

GHOST_BODY = "#bcd3e8"         # Mothwick - shy regular
GOLEM_BODY = "#7e7466"         # Grit - stone mason
WITCH_ROBE = "#7a42a8"         # Marrow - shopkeeper
WITCH_SKIN = "#a8d49a"

PLAYER_APRON = "#e0e4ec"       # the cook
PLAYER_SHIRT = "#d9503f"
PLAYER_HAIR = "#4a3324"
PLAYER_SKIN = "#f0bf94"
PLAYER_TROUSER = "#3f5a96"

# --- food -------------------------------------------------------------------
MEAT_RAW = "#d4718a"
MEAT_COOKED = "#a35a3c"
MEAT_BURNT = "#3b2b26"
BREAD = "#e8b45c"
CHEESE = "#ffd447"
SOUP_BASE = "#e08238"
MAGIC = "#c072f5"
MAGIC_LIGHT = "#e0b6ff"
SUGAR = "#f6dfe8"
BONE = "#e4dcc4"

# --- ui ---------------------------------------------------------------------
UI_PANEL = "#6b4224"
UI_PANEL_L = "#8a5730"
UI_EDGE = "#e8be7c"
UI_EDGE_HI = "#f0d9a8"
UI_TEXT = "#f4e9cd"
UI_TEXT_DIM = "#b09c85"
UI_GOOD = "#7fd44a"
UI_WARN = "#ffb037"
UI_BAD = "#e0503a"
UI_GOLD = "#ffd166"
UI_STAR = "#ffd75e"

# Quality tier colours - used by cooking result, food sprites and UI alike so
# the player learns one colour language.
QUALITY = {
    "raw": "#b8607f",
    "undercooked": "#d08a4a",
    "good": "#7ac74f",
    "perfect": "#ffd166",
    "overcooked": "#8a5a30",
    "burnt": "#3b2b26",
}

# Time-of-day ambient tints applied by the lighting layer at runtime.
TIME_TINT = {
    "morning": ("#ffd9a8", 0.14),
    "day": ("#ffffff", 0.00),
    "evening": ("#ff9d5c", 0.20),
    "night": ("#5a6fbf", 0.34),
}
