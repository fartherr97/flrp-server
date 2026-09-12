Config = {}
-- Fixed square world projection keeps text proportions correct at every zoom.
Config.TextureSize = 4096
Config.Bounds = { minX = -6000, maxX = 6000, minY = -4000, maxY = 8000 }
Config.Labels = {
    { text = 'MIAMI',       x = -100,  y = -800,  size = 80 },
    { text = 'NORTH MIAMI', x = 450,   y = 650,   size = 62 },
    { text = 'SOUTH MIAMI', x = 300,   y = -2100, size = 62 },
    { text = 'MIAMI BEACH', x = -1850, y = -400,  size = 58, rotation = -65 },
    { text = 'BROWARD COUNTY', x = 1000, y = 4300, size = 84 },
}
Config.Style = { font = 'Arial', fill = 'rgba(255,255,255,0.68)', outline = 'rgba(12,20,30,0.8)', outlineWidth = 5 }
