Config = {}

-- Default interact control (Space)
Config.InteractKey = 0xD9D0E1C0
Config.PromptGroupName = "Interact"

-- Defaults when option.hold / option.mash is true (or invalid)
Config.DefaultHoldTime = 1500
Config.DefaultMashCount = 10
-- Start progress (0.0-1.0) for mashDecay + onFail can-fail prompts
Config.DefaultMashStart = 0.0

Config.AimScreenRadius = 0.10
Config.MaxNearbySprites = 25

-- Center-screen aim cue when looking near an interact target
Config.ShowCenterDot = true
Config.CenterDotRadius = 0.18
Config.CenterDot = { w = 0.0035, h = 0.006, r = 255, g = 255, b = 255, a = 160 }
Config.CenterDotAimed = { w = 0.0045, h = 0.008, r = 255, g = 215, b = 0, a = 230 }

Config.SpriteDict = "mp_lobby_textures"
Config.SpriteName = "circle"
Config.SpriteQuiet = { w = 0.007, h = 0.012, r = 255, g = 255, b = 255, a = 90 }
Config.SpriteAimed = { w = 0.010, h = 0.017, r = 255, g = 215, b = 0, a = 220 }

-- World sprite size by distance: full size near interact range, smaller farther out
Config.SpriteScaleNear = 1.0
Config.SpriteScaleFar = 0.2

-- Default show / interact distances when a registration omits them
Config.DefaultDistance = 5.0
Config.DefaultInteractDistance = 2.0

-- Perf: entity/point scan rate, and sleep when idle / nearby-offscreen / drawing
Config.ScanInterval = 500
Config.IdleSleep = 750
Config.FarSleep = 100
Config.ActiveSleep = 0
