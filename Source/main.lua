import "CoreLibs/graphics"
local gfx = playdate.graphics
local geom = playdate.geometry
local pd = playdate

local ground_img = gfx.image.new("map.png")

local input_vector = geom.vector2D.new(0, 0)

local camera = {}
camera.worldX = 200
camera.worldY = 130
camera.direction = math.rad(0)
camera.near = 40
camera.far = 200
camera.depth = camera.far - camera.near
camera.fov_half = math.rad(45)
--camera.scale = 2
camera.x_scale = math.rad(45)/camera.fov_half
camera.map_size = 1024
camera.screen_width = 400
camera.screen_height = 240
-- camera.dxx = math.sin(camera.direction)
-- camera.dxy = math.cos(camera.direction)
-- camera.dyx = -math.cos(camera.direction)
-- camera.dyy = math.sin(camera.direction)
camera.sin_dir = math.sin(camera.direction)
camera.cos_dir = math.cos(camera.direction)

local dt = 1/30

-- setup test sprites
local sprites={}

for x=0, 1024, 16 do
    for y=0, 1024, 16 do
        table.insert(sprites,{["x"] = x, ["y"] = y})
    end
end

local state = 1 -- 1 = world coords, 2 = cam coords, 3 = projected

function playdate.update()
    
    if playdate.buttonJustPressed("a") then
        if state == 3 then
            state = 1
        else
            state += 1
        end
    end
    
    -- input handling
    camera.direction += input_vector.dx * dt
    camera.worldX += input_vector.dy * math.cos(camera.direction)
    camera.worldY += input_vector.dy * math.sin(camera.direction)
    
    -- update the rotation transform
    --setTransform(camera)
    
    -- update Frustum corner points
    local leftX = math.cos(camera.direction - camera.fov_half)
    local leftY = math.sin(camera.direction - camera.fov_half)
    local rightX = math.cos(camera.direction + camera.fov_half)
    local rightY = math.sin(camera.direction + camera.fov_half)
    
    camera.farX1 = camera.worldX + leftX * camera.far 
    camera.farY1 = camera.worldY + leftY * camera.far 
    camera.nearX1 = camera.worldX + leftX * camera.near 
    camera.nearY1 = camera.worldY + leftY * camera.near 
    camera.farX2 = camera.worldX + rightX * camera.far 
    camera.farY2 = camera.worldY + rightY * camera.far 
    camera.nearX2 = camera.worldX + rightX * camera.near 
    camera.nearY2 = camera.worldY + rightY * camera.near 

    -- update sin & cos of current direction (these are frequently accessed, so calc once and re-use)
    camera.sin_dir = math.sin(camera.direction)
    camera.cos_dir = math.cos(camera.direction)
    
    -- update camera frustum polygon
    local frustum = geom.polygon.new(camera.farX1, camera.farY1, camera.farX2, camera.farY2, 
        camera.nearX2, camera.nearY2, camera.nearX1, camera.nearY1)
    frustum:close()
    
    gfx.clear()
        
    if state == 1 then
        -- DRAW TOP-DOWN VIEW
        
        -- draw camera
        gfx.drawCircleAtPoint(camera.worldX, camera.worldY, 3)
        
        -- draw frustum
        gfx.drawPolygon(frustum)
        
        -- draw sprites
        for sprite = 1, #sprites do
            local sprX, sprY = sprites[sprite].x, sprites[sprite].y
            if frustum:containsPoint(sprX, sprY) then
                gfx.drawCircleAtPoint(sprX, sprY, 2)
            end
        end
        
        gfx.drawText('WORLD COORDINATES', 230, 220)
        
    elseif state == 2 then
        -- DRAW CAMERA VIEW
        
        -- draw camera
        gfx.drawCircleAtPoint(200, 240, 3)
        -- draw frustum
        
        local leftX = math.cos(math.rad(-90) - camera.fov_half)
        local leftY = math.sin(math.rad(-90) - camera.fov_half)
        local rightX = math.cos(math.rad(-90) + camera.fov_half)
        local rightY = math.sin(math.rad(-90) + camera.fov_half)
        local farX1 = 200 + leftX * camera.far 
        local farY1 = 240 + leftY * camera.far 
        local nearX1 = 200 + leftX * camera.near 
        local nearY1 = 240 + leftY * camera.near 
        local farX2 = 200 + rightX * camera.far 
        local farY2 = 240 + rightY * camera.far 
        local nearX2 = 200 + rightX * camera.near 
        local nearY2 = 240 + rightY * camera.near 
        local rot_frustum = geom.polygon.new(
            farX1, farY1, 
            farX2, farY2,
            nearX2, nearY2,
            nearX1, nearY1
            )
        rot_frustum:close()
        
        gfx.drawPolygon(rot_frustum)
        
        -- draw sprites
        for sprite = 1, #sprites do
            local sprX, sprY = sprites[sprite].x, sprites[sprite].y
            if frustum:containsPoint(sprX, sprY) then
                local x, y = projectedPoint(camera, sprX, sprY, "camera")
                gfx.drawCircleAtPoint(x, y, 2)
            end
        end    
    gfx.drawText('CAMERA COORDINATES', 220, 220)
    
    else
        -- DRAW PROJECTED VIEW
        -- draw sprites
        for sprite = 1, #sprites do
            local sprX, sprY = sprites[sprite].x, sprites[sprite].y
            if frustum:containsPoint(sprX, sprY) then
                local x, y, scale = projectedPoint(camera, sprX, sprY, "screen")
                gfx.drawRect(x, y, 500 * scale, 1000 * scale)
            end
        end
    gfx.drawText('SCREEN COORDINATES', 225, 220)
    
    end
    
    playdate.drawFPS(5,225)
    
    gfx.drawText("x: " .. math.floor(camera.worldX * 100)/100, 5, 5)
    gfx.drawText("y: " .. math.floor(camera.worldY * 100)/100, 5, 25)
    gfx.drawText("angle: " .. math.floor(math.deg(camera.direction) * 100)/100, 5, 45)
    
end

function projectedPoint(camera, x, y, projection)
    
    -- find point position relative to camera
    local camera_x = (x - camera.worldX)
    local camera_y = (y - camera.worldY)
    
    -- rotate to camera direction
    local rotated_x = (camera_x * camera.sin_dir - camera_y * camera.cos_dir)
    local rotated_y = (camera_x * camera.cos_dir + camera_y * camera.sin_dir)
    
    -- project to screen
    local distance = rotated_y - camera.near
    local screen_x = 200 - (rotated_x / distance) * 200 --* camera.x_scale
    local screen_y = (rotated_y / distance) * 120 - 140
    local scale = 1/distance
    
    -- print("space x/y: " .. rotated_x .. "/" .. rotated_y)
    -- print("screen x/y: " .. screen_x .. "/" .. screen_y)
    -- print("scale: " .. scale)
    
    if projection == "camera" then
        return 200 - rotated_x, 240 - rotated_y
    elseif projection == "screen" then
        return screen_x, screen_y, scale
    end
    
end

-- function setTransform(camera)
--     local direction = camera.direction
--     camera.dxx = math.sin(direction)
--     camera.dxy = math.cos(direction)
--     camera.dyx = -math.cos(direction)
--     camera.dyy = math.sin(direction)
--     
--     return camera
-- end

function playdate.leftButtonDown() input_vector.dx = -1 end
function playdate.leftButtonUp() input_vector.dx = 0 end
function playdate.rightButtonDown() input_vector.dx = 1 end
function playdate.rightButtonUp() input_vector.dx = 0 end
function playdate.upButtonDown() input_vector.dy = 1 end
function playdate.upButtonUp() input_vector.dy = 0 end
function playdate.downButtonDown() input_vector.dy = -1 end
function playdate.downButtonUp() input_vector.dy = 0 end
function playdate.AButtonDown() aDown = true end
function playdate.AButtonHeld() aHeld = true end
function playdate.AButtonUp() aDown = false aHeld = false end
function playdate.BButtonDown() bDown = true end
function playdate.BButtonHeld() bHeld = true end
function playdate.BButtonUp() bDown = false bHeld = false end
function playdate.cranked(change, accel)
    --camera.scale += change/10
    camera.far += change
    camera.near += change/4
    camera.depth = camera.far - camera.near
end