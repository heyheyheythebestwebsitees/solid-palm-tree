local InputService = game:GetService('UserInputService');
local TextService  = game:GetService('TextService');
local CoreGui      = game:GetService('CoreGui');
local Teams        = game:GetService('Teams');
local Players      = game:GetService('Players');
local RunService   = game:GetService('RunService');
local TweenService = game:GetService('TweenService');
local Lighting     = game:GetService('Lighting');
local HttpService  = game:GetService('HttpService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer   = Players.LocalPlayer;
local Mouse         = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles, Options = {}, {};
getgenv().Toggles = Toggles;
getgenv().Options = Options;

local Library = {
    Registry    = {};
    RegistryMap = {};
    HudRegistry = {};
    Signals     = {};
    ScreenGui   = ScreenGui;

    FontColor       = Color3.fromRGB(255, 255, 255);
    MainColor       = Color3.fromRGB(80, 88, 110);
    BackgroundColor = Color3.fromRGB(60, 68, 88);
    AccentColor     = Color3.fromRGB(0, 140, 255);
    OutlineColor    = Color3.fromRGB(150, 160, 185);
    RiskColor       = Color3.fromRGB(255, 50, 50);
    Black           = Color3.new(0, 0, 0);

    Font        = Enum.Font.Code;
    FontSize    = 14;
    OpenedFrames = {};
    DependencyBoxes = {};
    Toggled     = false;
    WireframeDrag = true;
    UseBlur     = false;
    BlurSize    = 15;
    KeybindMode = 'All';

    NotifyConfig = {
        Alignment = 'Left';
        BarSide   = 'Left';
        PositionX = 0;
        PositionY = 40;
    };
};

-- ============================================================
-- GLASS CONFIG  (fully adjustable — strength, tint, gloss)
-- ============================================================
Library.GlassConfig = {
    Strength        = 0.75,                  -- 0 = opaque, 1 = full glass
    GlossStrength   = 0.60,                  -- 0 = no shine, 1 = strong shine
    GlossColor      = Color3.fromRGB(255, 255, 255),
    GlossRotation   = 90,
    Tint            = nil,                   -- optional Color3
    TintMix         = 0.0,                   -- 0 = off, 1 = full tint
    EdgeStrokeTransparency = 0.5,
    EdgeStrokeThickness    = 1,
    BaseTransparency = {
        Panel      = 0.52,
        Background = 0.60,
        Small      = 0.38,
        Outer      = 0.78,
    },
};

Library.GlassFrames = {};

function Library:ComputeGlassTransparency(style)
    local base = Library.GlassConfig.BaseTransparency[style] or 0.5
    return math.clamp(base * Library.GlassConfig.Strength, 0, 0.95)
end

function Library:GetGlassGlossSequences()
    local cfg = Library.GlassConfig
    local glossColor = cfg.GlossColor or Color3.new(1, 1, 1)
    local lighter    = Library:GetLighterColor(glossColor)
    local darker     = Library:GetDarkerColor(glossColor)

    local cSeq = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, lighter),
        ColorSequenceKeypoint.new(0.45, glossColor),
        ColorSequenceKeypoint.new(1.0, darker),
    })

    local s = math.clamp(cfg.GlossStrength or 0.6, 0, 1)
    local topT = 1 - s * 0.10
    local midT = 1 - s
    local botT = 1 - s * 0.05

    local tSeq = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, math.clamp(topT, 0, 1)),
        NumberSequenceKeypoint.new(0.45, math.clamp(midT, 0, 1)),
        NumberSequenceKeypoint.new(1.0, math.clamp(botT, 0, 1)),
    })

    return cSeq, tSeq
end

function Library:ApplyGlass(Frame, Config)
    Config = Config or {}
    local style    = Config.Style or 'Panel'
    local addGloss = (Config.Gloss ~= false)

    if Frame:IsA('Frame') or Frame:IsA('ScrollingFrame') or Frame:IsA('TextButton') or Frame:IsA('ImageLabel') then
        Frame.BackgroundTransparency = Library:ComputeGlassTransparency(style)
    end

    table.insert(Library.GlassFrames, {
        Frame = Frame,
        Style = style,
        Gloss = addGloss,
    })

    if addGloss then
        local gloss = Instance.new('UIGradient')
        gloss.Name     = 'GlassGloss'
        gloss.Rotation = Library.GlassConfig.GlossRotation
        local cSeq, tSeq = Library:GetGlassGlossSequences()
        gloss.Color        = cSeq
        gloss.Transparency = tSeq
        gloss.Parent = Frame
        return gloss
    end
end

function Library:ApplyGlassEdge(Frame)
    local stroke = Instance.new('UIStroke')
    stroke.Name              = 'GlassEdge'
    stroke.Color             = Color3.fromRGB(255, 255, 255)
    stroke.Transparency      = Library.GlassConfig.EdgeStrokeTransparency
    stroke.Thickness         = Library.GlassConfig.EdgeStrokeThickness
    stroke.ApplyStrokeMode   = Enum.ApplyStrokeMode.Border
    stroke.Parent            = Frame
    return stroke
end

function Library:RefreshGlass()
    for i = #Library.GlassFrames, 1, -1 do
        local record = Library.GlassFrames[i]
        local Frame  = record.Frame
        if not Frame or not Frame.Parent then
            table.remove(Library.GlassFrames, i)
        else
            if Frame:IsA('Frame') or Frame:IsA('ScrollingFrame') or Frame:IsA('TextButton') or Frame:IsA('ImageLabel') then
                Frame.BackgroundTransparency = Library:ComputeGlassTransparency(record.Style)

                if Library.GlassConfig.Tint and (Library.GlassConfig.TintMix or 0) > 0 then
                    local reg = Library.RegistryMap[Frame]
                    local baseColor = Frame.BackgroundColor3
                    if reg and reg.Properties.BackgroundColor3 then
                        local idx = reg.Properties.BackgroundColor3
                        if type(idx) == 'string' and Library[idx] then
                            baseColor = Library[idx]
                        end
                    end
                    Frame.BackgroundColor3 = baseColor:Lerp(Library.GlassConfig.Tint, Library.GlassConfig.TintMix)
                end
            end

            if record.Gloss then
                local gloss = Frame:FindFirstChild('GlassGloss')
                if gloss and gloss:IsA('UIGradient') then
                    local cSeq, tSeq = Library:GetGlassGlossSequences()
                    gloss.Color        = cSeq
                    gloss.Transparency = tSeq
                    gloss.Rotation     = Library.GlassConfig.GlossRotation
                end
            end
        end
    end
end

-- ============================================================
-- PUBLIC GLASS CONTROLS
-- ============================================================
function Library:SetGlassStrength(v)
    self.GlassConfig.Strength = math.clamp(tonumber(v) or 0.75, 0, 1)
    self:RefreshGlass()
end

function Library:SetGlossStrength(v)
    self.GlassConfig.GlossStrength = math.clamp(tonumber(v) or 0.6, 0, 1)
    self:RefreshGlass()
end

function Library:SetGlossColor(color)
    if typeof(color) == 'Color3' then
        self.GlassConfig.GlossColor = color
        self:RefreshGlass()
    end
end

function Library:SetGlassTint(color, mix)
    if color == nil then
        self.GlassConfig.Tint = nil
        self.GlassConfig.TintMix = 0
    elseif typeof(color) == 'Color3' then
        self.GlassConfig.Tint = color
        self.GlassConfig.TintMix = math.clamp(tonumber(mix) or 0.5, 0, 1)
    end
    -- Re-run color registry first, then reapply tint
    self:UpdateColorsUsingRegistry()
end

-- ============================================================
-- THEME SYSTEM
-- ============================================================
Library.Themes = {
    Frosted = {
        Name = 'Frosted',
        MainColor       = Color3.fromRGB(80, 88, 110),
        BackgroundColor = Color3.fromRGB(60, 68, 88),
        AccentColor     = Color3.fromRGB(0, 140, 255),
        OutlineColor    = Color3.fromRGB(150, 160, 185),
        FontColor       = Color3.fromRGB(255, 255, 255),
        Glass = {
            Strength     = 0.75,
            GlossStrength= 0.60,
            GlossColor   = Color3.fromRGB(240, 250, 255),
            Tint         = nil,
            TintMix      = 0,
        },
    },
    Midnight = {
        Name = 'Midnight',
        MainColor       = Color3.fromRGB(28, 28, 32),
        BackgroundColor = Color3.fromRGB(20, 20, 24),
        AccentColor     = Color3.fromRGB(0, 110, 255),
        OutlineColor    = Color3.fromRGB(60, 60, 70),
        FontColor       = Color3.fromRGB(255, 255, 255),
        Glass = {
            Strength     = 0.72,
            GlossStrength= 0.80,
            GlossColor   = Color3.fromRGB(255, 255, 255),
            Tint         = nil,
            TintMix      = 0,
        },
    },
    Aqua = {
        Name = 'Aqua',
        MainColor       = Color3.fromRGB(60, 120, 140),
        BackgroundColor = Color3.fromRGB(40, 90, 110),
        AccentColor     = Color3.fromRGB(0, 220, 200),
        OutlineColor    = Color3.fromRGB(140, 210, 220),
        FontColor       = Color3.fromRGB(255, 255, 255),
        Glass = {
            Strength     = 0.78,
            GlossStrength= 0.55,
            GlossColor   = Color3.fromRGB(200, 255, 250),
            Tint         = nil,
            TintMix      = 0,
        },
    },
    Rose = {
        Name = 'Rose',
        MainColor       = Color3.fromRGB(120, 70, 100),
        BackgroundColor = Color3.fromRGB(90, 50, 75),
        AccentColor     = Color3.fromRGB(255, 90, 180),
        OutlineColor    = Color3.fromRGB(200, 150, 180),
        FontColor       = Color3.fromRGB(255, 255, 255),
        Glass = {
            Strength     = 0.78,
            GlossStrength= 0.55,
            GlossColor   = Color3.fromRGB(255, 210, 230),
            Tint         = nil,
            TintMix      = 0,
        },
    },
    Blood = {
        Name = 'Blood',
        MainColor       = Color3.fromRGB(90, 30, 30),
        BackgroundColor = Color3.fromRGB(60, 20, 20),
        AccentColor     = Color3.fromRGB(220, 40, 40),
        OutlineColor    = Color3.fromRGB(180, 100, 100),
        FontColor       = Color3.fromRGB(255, 240, 240),
        Glass = {
            Strength     = 0.76,
            GlossStrength= 0.65,
            GlossColor   = Color3.fromRGB(255, 200, 200),
            Tint         = nil,
            TintMix      = 0,
        },
    },
    Emerald = {
        Name = 'Emerald',
        MainColor       = Color3.fromRGB(40, 90, 60),
        BackgroundColor = Color3.fromRGB(25, 65, 40),
        AccentColor     = Color3.fromRGB(40, 210, 120),
        OutlineColor    = Color3.fromRGB(120, 190, 150),
        FontColor       = Color3.fromRGB(240, 255, 245),
        Glass = {
            Strength     = 0.76,
            GlossStrength= 0.60,
            GlossColor   = Color3.fromRGB(200, 255, 220),
            Tint         = nil,
            TintMix      = 0,
        },
    },
};

Library.CurrentThemeName = 'Frosted';
Library.CustomThemes = {};

function Library:SetTheme(theme)
    if type(theme) == 'string' then
        theme = Library.Themes[theme] or Library.CustomThemes[theme]
    end
    if type(theme) ~= 'table' then
        return false, 'Invalid theme'
    end

    for _, key in ipairs({ 'MainColor', 'BackgroundColor', 'AccentColor', 'OutlineColor', 'FontColor' }) do
        if theme[key] then
            Library[key] = theme[key]
        end
    end

    if theme.Glass then
        for k, v in pairs(theme.Glass) do
            Library.GlassConfig[k] = v
        end
    end

    Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)
    Library.CurrentThemeName = theme.Name or Library.CurrentThemeName

    Library:UpdateColorsUsingRegistry()
    return true
end

function Library:GetCurrentThemeAsTable()
    local t = {
        Name            = Library.CurrentThemeName,
        MainColor       = Library.MainColor,
        BackgroundColor = Library.BackgroundColor,
        AccentColor     = Library.AccentColor,
        OutlineColor    = Library.OutlineColor,
        FontColor       = Library.FontColor,
        Glass = {
            Strength      = Library.GlassConfig.Strength,
            GlossStrength = Library.GlassConfig.GlossStrength,
            GlossColor    = Library.GlassConfig.GlossColor,
            Tint          = Library.GlassConfig.Tint,
            TintMix       = Library.GlassConfig.TintMix,
        },
    }
    return t
end

-- ============================================================
-- BLUR / RAINBOW / FONT
-- ============================================================
Library.KeyPickerList = {};

Library.BlurEffect = Instance.new("BlurEffect")
Library.BlurEffect.Name    = "LinoriaBlur"
Library.BlurEffect.Size    = 0
Library.BlurEffect.Enabled = false
pcall(function() Library.BlurEffect.Parent = Lighting end)

function Library:UpdateBlur()
    if Library.UseBlur then
        if Library.Toggled then
            Library.BlurEffect.Enabled = true
            TweenService:Create(Library.BlurEffect, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {Size = Library.BlurSize}):Play()
        end
    else
        local tween = TweenService:Create(Library.BlurEffect, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {Size = 0})
        tween:Play()
        task.delay(0.2, function()
            if not Library.UseBlur then Library.BlurEffect.Enabled = false end
        end)
    end
end

function Library:SetFontSize(Size)
    Library.FontSize = Size
    for _, d in pairs(ScreenGui:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextBox") or d:IsA("TextButton") then
            local offset = d:GetAttribute("FontSizeOffset")
            if offset then d.TextSize = Size + offset end
        end
    end
    local mobile = CoreGui:FindFirstChild("LinoriaMobileUI")
    if mobile then
        for _, d in pairs(mobile:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextBox") or d:IsA("TextButton") then
                local offset = d:GetAttribute("FontSizeOffset")
                if offset then d.TextSize = Size + offset end
            end
        end
    end
end

local RainbowStep, Hue = 0, 0
table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta
    if RainbowStep >= (1/60) then
        RainbowStep = 0
        Hue = Hue + (1/400)
        if Hue > 1 then Hue = 0 end
        Library.CurrentRainbowHue   = Hue
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1)
    end
end))

-- ============================================================
-- HELPERS
-- ============================================================
local function GetPlayersString()
    local list = Players:GetPlayers()
    for i = 1, #list do list[i] = list[i].Name end
    table.sort(list, function(a, b) return a < b end)
    return list
end

local function GetTeamsString()
    local list = Teams:GetTeams()
    for i = 1, #list do list[i] = list[i].Name end
    table.sort(list, function(a, b) return a < b end)
    return list
end

function Library:SafeCallback(f, ...)
    if not f then return end
    if not Library.NotifyOnError then return f(...) end
    local ok, err = pcall(f, ...)
    if not ok then
        local _, i = err:find(":%d+: ")
        if not i then return Library:Notify(err) end
        return Library:Notify(err:sub(i + 1), 3)
    end
end

function Library:AttemptSave()
    if Library.SaveManager then Library.SaveManager:Save() end
end

function Library:Create(Class, Properties)
    local inst = Class
    if type(Class) == 'string' then inst = Instance.new(Class) end
    for p, v in next, Properties do inst[p] = v end
    if inst:IsA("TextLabel") or inst:IsA("TextBox") or inst:IsA("TextButton") then
        if Properties.TextSize then
            inst:SetAttribute("FontSizeOffset", Properties.TextSize - Library.FontSize)
        else
            inst:SetAttribute("FontSizeOffset", 0)
        end
    end
    return inst
end

function Library:ApplyTextStroke(inst)
    inst.TextStrokeTransparency = 1
    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = inst;
    })
end

function Library:ApplyGlow(inst) end

function Library:CreateLabel(Properties, IsHud)
    local inst = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font           = Library.Font;
        TextColor3     = Library.FontColor;
        TextSize       = Library.FontSize + 2;
        TextStrokeTransparency = 0;
    })
    Library:ApplyTextStroke(inst)
    Library:AddToRegistry(inst, { TextColor3 = 'FontColor' }, IsHud)
    return Library:Create(inst, Properties)
end

function Library:MakeDraggable(Instance, Cutoff, IsWindow)
    Instance.Active = true
    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
            local StartPos = Instance.Position
            local DragStart = Input.Position
            if (DragStart.Y - Instance.AbsolutePosition.Y) > (Cutoff or 40) then return end

            local Dragging = true
            local HasMoved = false
            local Wireframe = nil

            local ChangedConn = InputService.InputChanged:Connect(function(Change)
                if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                    local Delta = Change.Position - DragStart
                    if IsWindow and Library.WireframeDrag then
                        if not HasMoved and Delta.Magnitude > 2 then
                            HasMoved = true
                            Wireframe = Library:Create("Frame", {
                                Size = Instance.Size, Position = Instance.Position,
                                AnchorPoint = Instance.AnchorPoint, BackgroundTransparency = 1,
                                Active = false, ZIndex = 100000, Parent = ScreenGui,
                            })
                            Library:Create("UIStroke", {
                                Color = Color3.fromRGB(255, 255, 255), Thickness = 1,
                                ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Wireframe,
                            })
                        end
                        if HasMoved and Wireframe then
                            Wireframe.Position = UDim2.new(
                                StartPos.X.Scale, StartPos.X.Offset + Delta.X,
                                StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
                        end
                    else
                        Instance.Position = UDim2.new(
                            StartPos.X.Scale, StartPos.X.Offset + Delta.X,
                            StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
                    end
                end
            end)

            local EndedConn = InputService.InputEnded:Connect(function(EndInput)
                if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
                    Dragging = false
                    ChangedConn:Disconnect()
                    EndedConn:Disconnect()
                    if IsWindow and Library.WireframeDrag and HasMoved and Wireframe then
                        Instance.Position = Wireframe.Position
                        Wireframe:Destroy()
                        Wireframe = nil
                    end
                end
            end)
        end
    end)
end

function Library:MakeResizable(Instance, MinSize, MaxSize)
    MinSize = MinSize or Vector2.new(400, 300)
    MaxSize = MaxSize or Vector2.new(1400, 1000)

    local Grip = Library:Create('TextButton', {
        Name = 'ResizeGrip', Text = '', AutoButtonColor = false,
        BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(1, -4, 1, -4), AnchorPoint = Vector2.new(1, 1),
        ZIndex = 25, Parent = Instance,
    })
    local GripIcon = Library:CreateLabel({
        BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(1, 0, 1, 0), AnchorPoint = Vector2.new(1, 1),
        Text = '◢', TextColor3 = Library.OutlineColor, TextSize = Library.FontSize + 2,
        ZIndex = 26, Parent = Grip,
    })
    Library:AddToRegistry(GripIcon, { TextColor3 = 'OutlineColor' })

    Grip.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
        local StartSize = Instance.Size
        local DragStart = Input.Position
        local HasMoved = false
        local Wireframe = nil

        local ChangedConn = InputService.InputChanged:Connect(function(Change)
            if Change.UserInputType ~= Enum.UserInputType.MouseMovement and Change ~= Input then return end
            local Delta = Change.Position - DragStart
            if Delta.Magnitude <= 2 then return end
            HasMoved = true
            local newSize = UDim2.fromOffset(
                math.clamp(StartSize.X.Offset + Delta.X, MinSize.X, MaxSize.X),
                math.clamp(StartSize.Y.Offset + Delta.Y, MinSize.Y, MaxSize.Y))
            if Library.WireframeDrag then
                if not Wireframe then
                    Wireframe = Library:Create('Frame', {
                        Size = Instance.Size, Position = Instance.Position,
                        AnchorPoint = Instance.AnchorPoint, BackgroundTransparency = 1,
                        Active = false, ZIndex = 100000, Parent = ScreenGui,
                    })
                    Library:Create('UIStroke', {
                        Color = Color3.fromRGB(255, 255, 255), Thickness = 1,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Wireframe,
                    })
                end
                Wireframe.Size = newSize
                Wireframe.Position = Instance.Position
            else
                Instance.Size = newSize
            end
        end)

        local EndedConn = InputService.InputEnded:Connect(function(EndInput)
            if EndInput ~= Input and EndInput.UserInputType ~= Enum.UserInputType.Touch then return end
            ChangedConn:Disconnect()
            EndedConn:Disconnect()
            if Library.WireframeDrag and HasMoved and Wireframe then
                Instance.Size = Wireframe.Size
                Wireframe:Destroy()
            end
        end)
    end)
end

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, Library.FontSize)
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,
        Size = UDim2.fromOffset(X + 5, Y + 4),
        ZIndex = 100, Parent = Library.ScreenGui, Visible = false,
    })
    Library:ApplyGlass(Tooltip, { Style = 'Small' })

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1), Size = UDim2.fromOffset(X, Y),
        TextSize = Library.FontSize, Text = InfoStr,
        TextColor3 = Library.FontColor, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Tooltip.ZIndex + 1, Parent = Tooltip,
    })
    Library:AddToRegistry(Tooltip, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
    Library:AddToRegistry(Label, { TextColor3 = 'FontColor' })

    local IsHovering = false
    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        IsHovering = true
        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true
        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)
    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance]
        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx
            if Reg and Reg.Properties[Property] then Reg.Properties[Property] = ColorIdx end
        end
    end)
    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance]
        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx
            if Reg and Reg.Properties[Property] then Reg.Properties[Property] = ColorIdx end
        end
    end)
end

function Library:MouseIsOverOpenedFrame()
    for Frame in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then return true end
    end
end

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
    return Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y
end

function Library:UpdateDependencyBoxes()
    for _, d in next, Library.DependencyBoxes do d:Update() end
end

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB
end

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color)
    return Color3.fromHSV(H, S, V / 1.5)
end

function Library:GetLighterColor(Color)
    local H, S, V = Color3.toHSV(Color)
    return Color3.fromHSV(H, math.max(S * 0.5, 0.05), math.min(V * 1.4, 1))
end

Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1
    local Data = { Instance = Instance; Properties = Properties; Idx = Idx }
    table.insert(Library.Registry, Data)
    Library.RegistryMap[Instance] = Data
    if IsHud then table.insert(Library.HudRegistry, Data) end
end

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance]
    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then table.remove(Library.Registry, Idx) end
        end
        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then table.remove(Library.HudRegistry, Idx) end
        end
        Library.RegistryMap[Instance] = nil
    end
end

function Library:UpdateColorsUsingRegistry()
    Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)
    for _, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx]
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end
    end
    if Library.RefreshGlass then Library:RefreshGlass() end
end

function Library:GiveSignal(Signal) table.insert(Library.Signals, Signal) end

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Conn = table.remove(Library.Signals, Idx)
        Conn:Disconnect()
    end
    if Library.OnUnload then Library.OnUnload() end
    if Library.BlurEffect then Library.BlurEffect:Destroy() end
    ScreenGui:Destroy()
end

function Library:OnUnload(Callback) Library.OnUnload = Callback end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then Library:RemoveFromRegistry(Instance) end
end))

-- ============================================================
-- SAVE MANAGER
-- ============================================================
local SaveManager = {}
SaveManager.__index = SaveManager
SaveManager.Folder = "LinoriaGlass"
SaveManager.SubFolder = "configs"
SaveManager.Ignore = {}
SaveManager.LoadedConfig = nil

function SaveManager.new(library)
    local self = setmetatable({}, SaveManager)
    self.Library = library
    library.SaveManager = self
    return self
end

function SaveManager:SetFolder(path)
    self.Folder = path
    self:BuildTree()
end

function SaveManager:SetSubFolder(sub)
    self.SubFolder = sub
    self:BuildTree()
end

function SaveManager:SetIgnoreIndexes(list)
    for _, key in next, list do self.Ignore[key] = true end
end

function SaveManager:GetFolderPath()
    if self.SubFolder and self.SubFolder ~= "" then
        return self.Folder .. "/" .. self.SubFolder
    end
    return self.Folder
end

function SaveManager:BuildTree()
    local combined = self:GetFolderPath()
    local current = ""
    for segment in combined:gmatch("[^/]+") do
        current = (current == "" and segment) or (current .. "/" .. segment)
        if not isfolder(current) then pcall(makefolder, current) end
    end
end

function SaveManager:GetConfigList()
    local folder = self:GetFolderPath()
    if not isfolder(folder) then self:BuildTree() end
    local list, names = listfiles(folder), {}
    for _, file in next, list do
        if not isfolder(file) then
            local name = file:match("([^/\\]+)%.json$")
            if name then table.insert(names, name) end
        end
    end
    table.sort(names)
    return names
end

function SaveManager:GetConfigPath(name)
    return string.format("%s/%s.json", self:GetFolderPath(), name)
end

local ElementParser = {
    Toggle = {
        Save = function(idx, obj) return { type = 'Toggle', idx = idx, value = obj.Value } end,
        Load = function(idx, data) if Options[idx] then Options[idx]:SetValue(data.value) end end,
    },
    Slider = {
        Save = function(idx, obj) return { type = 'Slider', idx = idx, value = obj.Value } end,
        Load = function(idx, data) if Options[idx] then Options[idx]:SetValue(data.value) end end,
    },
    Dropdown = {
        Save = function(idx, obj) return { type = 'Dropdown', idx = idx, value = obj.Value } end,
        Load = function(idx, data) if Options[idx] then Options[idx]:SetValue(data.value) end end,
    },
    ColorPicker = {
        Save = function(idx, obj)
            return { type = 'ColorPicker', idx = idx, value = obj.Value:ToHex(), transparency = obj.Transparency }
        end,
        Load = function(idx, data)
            if Options[idx] then
                Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
            end
        end,
    },
    KeyPicker = {
        Save = function(idx, obj)
            return { type = 'KeyPicker', idx = idx, key = obj.Value, mode = obj.Mode, toggled = obj.Toggled }
        end,
        Load = function(idx, data)
            if Options[idx] then
                Options[idx]:SetValue({ data.key, data.mode })
                Options[idx].Toggled = data.toggled or false
            end
        end,
    },
    Input = {
        Save = function(idx, obj) return { type = 'Input', idx = idx, value = obj.Value } end,
        Load = function(idx, data) if Options[idx] then Options[idx]:SetValue(data.value) end end,
    },
}

function SaveManager:Save(name)
    name = name or self.LoadedConfig
    if not name or name == "" then return false, "Invalid name" end
    if name:lower() == "autoload" and not self.LoadedConfig then
        -- allowed
    end
    self:BuildTree()

    local data = {
        version = 3.0,
        timestamp = os.date("%d.%m.%Y %H:%M:%S"),
        objects = {},
        theme = {
            name = self.Library.CurrentThemeName,
            custom = self.Library.CustomThemes,
            glass = {
                Strength = self.Library.GlassConfig.Strength,
                GlossStrength = self.Library.GlassConfig.GlossStrength,
                GlossColor = self.Library.GlassConfig.GlossColor and self.Library.GlassConfig.GlossColor:ToHex() or nil,
                Tint = self.Library.GlassConfig.Tint and self.Library.GlassConfig.Tint:ToHex() or nil,
                TintMix = self.Library.GlassConfig.TintMix,
            },
        },
    }

    for idx, toggle in next, Toggles do
        if not self.Ignore[idx] then
            local parser = ElementParser[toggle.Type]
            if parser then table.insert(data.objects, parser.Save(idx, toggle)) end
        end
    end
    for idx, option in next, Options do
        if not self.Ignore[idx] then
            local parser = ElementParser[option.Type]
            if parser then table.insert(data.objects, parser.Save(idx, option)) end
        end
    end

    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then return false, "Failed to encode" end

    local wrote = pcall(writefile, self:GetConfigPath(name), encoded)
    if not wrote then return false, "Failed to write" end

    self.LoadedConfig = name
    return true
end

function SaveManager:Load(name)
    local path = self:GetConfigPath(name)
    if not isfile(path) then return false, "Config not found" end
    local ok, raw = pcall(readfile, path)
    if not ok then return false, "Failed to read" end
    local dec, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not dec or type(data) ~= "table" then return false, "Failed to decode" end
    if not data.version or data.version < 2.0 then return false, "Outdated config" end

    local prevSaveManager = self.Library.SaveManager
    self.Library.SaveManager = nil

    if data.theme then
        if data.theme.custom then
            for k, v in pairs(data.theme.custom) do
                self.Library.CustomThemes[k] = v
            end
        end
        if data.theme.name and self.Library.Themes[data.theme.name] then
            self.Library:SetTheme(data.theme.name)
        end
        if data.theme.glass then
            local g = data.theme.glass
            if g.Strength then self.Library.GlassConfig.Strength = g.Strength end
            if g.GlossStrength then self.Library.GlassConfig.GlossStrength = g.GlossStrength end
            if g.GlossColor then self.Library.GlassConfig.GlossColor = Color3.fromHex(g.GlossColor) end
            if g.Tint then self.Library.GlassConfig.Tint = Color3.fromHex(g.Tint) end
            if g.TintMix then self.Library.GlassConfig.TintMix = g.TintMix end
            self.Library:UpdateColorsUsingRegistry()
        end
    end

    for _, obj in next, data.objects do
        if not self.Ignore[obj.idx] then
            local parser = ElementParser[obj.type]
            if parser then pcall(parser.Load, obj.idx, obj) end
        end
    end

    self.Library.SaveManager = prevSaveManager
    self.LoadedConfig = name
    return true
end

function SaveManager:Delete(name)
    local path = self:GetConfigPath(name)
    if not isfile(path) then return false, "Not found" end
    local ok = pcall(delfile, path)
    if not ok then return false, "Failed to delete" end
    if self.LoadedConfig == name then self.LoadedConfig = nil end
    return true
end

function SaveManager:Check()
    local folder = self:GetFolderPath()
    if not isfolder(folder) then return end
    for _, file in next, listfiles(folder) do
        if not isfolder(file) then
            local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(file)) end)
            if ok and type(decoded) == 'table' and decoded.version and decoded.version < 2.0 then
                pcall(delfile, file)
            end
        end
    end
end

-- SaveManager UI builder
function SaveManager:BuildUI(groupbox)
    if not groupbox then return end

    groupbox:AddLabel('Config Manager'):AddColorPicker('SaveManagerColor', {
        Default = Library.AccentColor,
        Title = 'Accent Color',
        Callback = function(c)
            Library.AccentColor = c
            Library:UpdateColorsUsingRegistry()
        end,
    })

    groupbox:AddInput('SaveManagerName', {
        Text = 'Config name',
        Default = '',
        Placeholder = 'my_config',
        Finished = true,
        Tooltip = 'Name to save/load',
    })

    local configList = groupbox:AddDropdown('SaveManagerList', {
        Text = 'Config list',
        Values = self:GetConfigList(),
        Default = '',
        AllowNull = true,
        Tooltip = 'Select a saved config',
        Callback = function(value) self.Selected = value end,
    })

    local saveBtn = groupbox:AddButton({
        Text = 'Save Config',
        Func = function()
            local name = Options.SaveManagerName and Options.SaveManagerName.Value
            if not name or name == '' then
                return Library:Notify('Enter a config name first', 3)
            end
            local ok = self:Save(name)
            if ok then
                configList:SetValues(self:GetConfigList())
                configList:SetValue(name)
                Library:Notify('Saved: ' .. name, 3)
            else
                Library:Notify('Save failed', 3)
            end
        end,
    })

    saveBtn:AddButton({
        Text = 'Load Config',
        Func = function()
            local name = configList.Value
            if not name or name == '' then return Library:Notify('Select a config', 3) end
            local ok = self:Load(name)
            Library:Notify(ok and ('Loaded: ' .. name) or 'Load failed', 3)
        end,
    })

    local delBtn = groupbox:AddButton({
        Text = 'Delete Config',
        Func = function()
            local name = configList.Value
            if not name or name == '' then return Library:Notify('Select a config', 3) end
            local ok = self:Delete(name)
            if ok then
                configList:SetValues(self:GetConfigList())
                Library:Notify('Deleted: ' .. name, 3)
            end
        end,
    })

    delBtn:AddButton({
        Text = 'Refresh List',
        Func = function()
            configList:SetValues(self:GetConfigList())
            Library:Notify('Config list refreshed', 2)
        end,
    })
end

Library.SaveManagerClass = SaveManager

-- ============================================================
-- THEME MANAGER
-- ============================================================
local ThemeManager = {}
ThemeManager.__index = ThemeManager

function ThemeManager.new(library)
    return setmetatable({ Library = library, Selected = nil }, ThemeManager)
end

function ThemeManager:RefreshList(dropdown)
    local names = {}
    for k in pairs(self.Library.Themes) do table.insert(names, k) end
    for k in pairs(self.Library.CustomThemes) do table.insert(names, k) end
    table.sort(names)
    if dropdown then dropdown:SetValues(names) end
    return names
end

function ThemeManager:BuildUI(groupbox)
    if not groupbox then return end

    groupbox:AddLabel('Theme Manager')

    local themeList = groupbox:AddDropdown('ThemeManager_ThemeList', {
        Text = 'Theme',
        Values = self:RefreshList(),
        Default = self.Library.CurrentThemeName,
        AllowNull = false,
        Tooltip = 'Pick a theme',
        Callback = function(value)
            self.Selected = value
            local ok = self.Library:SetTheme(value)
            if ok then Library:Notify('Theme: ' .. value, 2) end
        end,
    })

    groupbox:AddDivider()
    groupbox:AddLabel('Glass Controls')

    local glassStrength = groupbox:AddSlider('ThemeManager_GlassStrength', {
        Text = 'Glass Strength',
        Min = 0, Max = 1, Rounding = 2,
        Default = self.Library.GlassConfig.Strength,
        Tooltip = '0 = opaque, 1 = full glass',
        Callback = function(v)
            self.Library.GlassConfig.Strength = v
            self.Library:RefreshGlass()
        end,
    })

    local glossStrength = groupbox:AddSlider('ThemeManager_GlossStrength', {
        Text = 'Gloss Strength',
        Min = 0, Max = 1, Rounding = 2,
        Default = self.Library.GlassConfig.GlossStrength,
        Tooltip = '0 = no shine, 1 = strong shine',
        Callback = function(v)
            self.Library.GlassConfig.GlossStrength = v
            self.Library:RefreshGlass()
        end,
    })

    groupbox:AddLabel('Glass / Gloss Color'):AddColorPicker('ThemeManager_GlassColor', {
        Default = self.Library.GlassConfig.GlossColor,
        Title = 'Gloss Color',
        Callback = function(c)
            self.Library.GlassConfig.GlossColor = c
            self.Library:RefreshGlass()
        end,
    })

    groupbox:AddDivider()
    groupbox:AddLabel('Custom Theme')

    groupbox:AddInput('ThemeManager_CustomName', {
        Text = 'Theme Name',
        Default = '',
        Placeholder = 'MyCustomTheme',
        Finished = true,
    })

    groupbox:AddButton({
        Text = 'Save Current as Custom',
        Func = function()
            local name = Options.ThemeManager_CustomName and Options.ThemeManager_CustomName.Value
            if not name or name == '' then return Library:Notify('Enter a theme name', 3) end
            local theme = self.Library:GetCurrentThemeAsTable()
            theme.Name = name
            self.Library.CustomThemes[name] = theme
            self:RefreshList(themeList)
            Library:Notify('Saved theme: ' .. name, 3)
        end,
    }):AddButton({
        Text = 'Delete Custom',
        Func = function()
            local name = Options.ThemeManager_ThemeList and Options.ThemeManager_ThemeList.Value
            if not name or not self.Library.CustomThemes[name] then
                return Library:Notify('Not a custom theme', 3)
            end
            self.Library.CustomThemes[name] = nil
            self:RefreshList(themeList)
            Library:Notify('Deleted theme: ' .. name, 3)
        end,
    })

    return {
        ThemeList = themeList,
        GlassStrength = glassStrength,
        GlossStrength = glossStrength,
    }
end

Library.ThemeManagerClass = ThemeManager

-- ============================================================
-- BASE ADDONS (ColorPicker, KeyPicker)
-- ============================================================
local BaseAddons = {}
do
    local Funcs = {}

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel
        assert(Info.Default, 'AddColorPicker: Missing default.')

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker';
            Callback = Info.Callback or function(Color) end;
        }

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color)
            ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = H, S, V
        end

        ColorPicker:SetHSVFromRGB(ColorPicker.Value)
        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value,
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value),
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(0, 28, 0, 14), ZIndex = 6, Parent = ToggleLabel,
        })
        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0, Size = UDim2.new(0, 27, 0, 13), ZIndex = 5,
            Image = 'http://www.roblox.com/asset/?id=12977615774',
            Visible = not not Info.Transparency, Parent = DisplayFrame,
        })

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color', BackgroundColor3 = Color3.new(1,1,1),
            BorderColor3 = Color3.new(0,0,0),
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253),
            Visible = false, ZIndex = 15, Parent = ScreenGui,
        })
        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18)
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor,
            BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 16, Parent = PickerFrameOuter,
        })
        Library:ApplyGlass(PickerFrameInner, { Style = 'Background' })

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 2), ZIndex = 17, Parent = PickerFrameInner,
        })

        local SatVibMapOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0,0,0),
            Position = UDim2.new(0, 4, 0, 25),
            Size = UDim2.new(0, 200, 0, 200), ZIndex = 17, Parent = PickerFrameInner,
        })
        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor,
            BorderColor3 = Library.OutlineColor, BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 18, Parent = SatVibMapOuter,
        })
        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 18, Image = 'rbxassetid://4155801252', Parent = SatVibMapInner,
        })
        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 6, 0, 6),
            BackgroundTransparency = 1,
            Image = 'http://www.roblox.com/asset/?id=9619665977',
            ImageColor3 = Color3.new(0,0,0), ZIndex = 19, Parent = SatVibMap,
        })
        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2),
            Position = UDim2.new(0, 1, 0, 1), BackgroundTransparency = 1,
            Image = 'http://www.roblox.com/asset/?id=9619665977',
            ZIndex = 20, Parent = CursorOuter,
        })

        local HueSelectorOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0,0,0),
            Position = UDim2.new(0, 208, 0, 25),
            Size = UDim2.new(0, 15, 0, 200), ZIndex = 17, Parent = PickerFrameInner,
        })
        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 18, Parent = HueSelectorOuter,
        })
        local HueCursor = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1,1,1),
            AnchorPoint = Vector2.new(0, 0.5),
            BorderColor3 = Color3.new(0,0,0),
            Size = UDim2.new(1, 0, 0, 1), ZIndex = 18, Parent = HueSelectorInner,
        })

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0,0,0),
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20), ZIndex = 18, Parent = PickerFrameInner,
        })
        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor, BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 18, Parent = HueBoxOuter,
        })
        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212,212,212)),
            }),
            Rotation = 90, Parent = HueBoxInner,
        })

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 5, 0, 0),
            Size = UDim2.new(1, -5, 1, 0),
            Font = Library.Font,
            PlaceholderColor3 = Color3.fromRGB(190,190,190),
            PlaceholderText = 'Hex color', Text = '#FFFFFF',
            TextColor3 = Library.FontColor, TextSize = Library.FontSize,
            TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 20, Parent = HueBoxInner,
        })
        Library:ApplyTextStroke(HueBox)

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20), Parent = PickerFrameInner,
        })
        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255', PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor,
        })

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor
        if Info.Transparency then
            TransparencyBoxOuter = Library:Create('Frame', {
                BorderColor3 = Color3.new(0,0,0),
                Position = UDim2.fromOffset(4, 251),
                Size = UDim2.new(1, -8, 0, 15), ZIndex = 19, Parent = PickerFrameInner,
            })
            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value,
                BorderColor3 = Library.OutlineColor, BorderMode = Enum.BorderMode.Inset,
                Size = UDim2.new(1, 0, 1, 0), ZIndex = 19, Parent = TransparencyBoxOuter,
            })
            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' })
            Library:Create('ImageLabel', {
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
                Image = 'http://www.roblox.com/asset/?id=12978095818',
                ZIndex = 20, Parent = TransparencyBoxInner,
            })
            TransparencyCursor = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(1,1,1),
                AnchorPoint = Vector2.new(0.5, 0),
                BorderColor3 = Color3.new(0,0,0),
                Size = UDim2.new(0, 1, 1, 0), ZIndex = 21, Parent = TransparencyBoxInner,
            })
        end

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14),
            Position = UDim2.fromOffset(5, 5),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextSize = Library.FontSize, Text = ColorPicker.Title,
            TextWrapped = false, ZIndex = 16, Parent = PickerFrameInner,
        })

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor' })
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })
        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor' })
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor' })

        local SequenceTable = {}
        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)))
        end
        Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable),
            Rotation = 90, Parent = HueSelectorInner,
        })

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local ok, result = pcall(Color3.fromHex, HueBox.Text)
                if ok and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end
            ColorPicker:Display()
        end)
        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end
            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1)
            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value,
                BackgroundTransparency = ColorPicker.Transparency,
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value),
            })
            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0)
            end
            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0)
            HueCursor.Position   = UDim2.new(0, 0, ColorPicker.Hue, 0)
            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({
                math.floor(ColorPicker.Value.R * 255),
                math.floor(ColorPicker.Value.G * 255),
                math.floor(ColorPicker.Value.B * 255),
            }, ', ')
            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value)
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value)
        end

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func
            Func(ColorPicker.Value)
        end

        function ColorPicker:Show()
            for Frame in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false
                    Library.OpenedFrames[Frame] = nil
                end
            end
            PickerFrameOuter.Visible = true
            Library.OpenedFrames[PickerFrameOuter] = true
        end

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false
            Library.OpenedFrames[PickerFrameOuter] = nil
        end

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3])
            ColorPicker.Transparency = Transparency or 0
            ColorPicker:SetHSVFromRGB(Color)
            ColorPicker:Display()
        end

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0
            ColorPicker:SetHSVFromRGB(Color)
            ColorPicker:Display()
        end

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                local function UpdateColor(PosX, PosY)
                    local MinX = SatVibMap.AbsolutePosition.X
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X
                    local MouseX = math.clamp(PosX, MinX, MaxX)
                    local MinY = SatVibMap.AbsolutePosition.Y
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y
                    local MouseY = math.clamp(PosY, MinY, MaxY)
                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX)
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY))
                    ColorPicker:Display()
                end
                UpdateColor(Input.Position.X, Input.Position.Y)
                local ChangedConn = InputService.InputChanged:Connect(function(Change)
                    if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                        UpdateColor(Change.Position.X, Change.Position.Y)
                    end
                end)
                local EndedConn
                EndedConn = InputService.InputEnded:Connect(function(EndInput)
                    if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
                        ChangedConn:Disconnect()
                        EndedConn:Disconnect()
                        Library:AttemptSave()
                    end
                end)
            end
        end)

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                local function UpdateHue(PosY)
                    local MinY = HueSelectorInner.AbsolutePosition.Y
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y
                    local MouseY = math.clamp(PosY, MinY, MaxY)
                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY))
                    ColorPicker:Display()
                end
                UpdateHue(Input.Position.Y)
                local ChangedConn = InputService.InputChanged:Connect(function(Change)
                    if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                        UpdateHue(Change.Position.Y)
                    end
                end)
                local EndedConn
                EndedConn = InputService.InputEnded:Connect(function(EndInput)
                    if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
                        ChangedConn:Disconnect()
                        EndedConn:Disconnect()
                        Library:AttemptSave()
                    end
                end)
            end
        end)

        DisplayFrame.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then ColorPicker:Hide() else ColorPicker:Show() end
            end
        end)

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                    local function UpdateAlpha(PosX)
                        local MinX = TransparencyBoxInner.AbsolutePosition.X
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X
                        local MouseX = math.clamp(PosX, MinX, MaxX)
                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX))
                        ColorPicker:Display()
                    end
                    UpdateAlpha(Input.Position.X)
                    local ChangedConn = InputService.InputChanged:Connect(function(Change)
                        if Change.UserInputType == Enum.UserInputType.MouseMovement or Change == Input then
                            UpdateAlpha(Change.Position.X)
                        end
                    end)
                    local EndedConn
                    EndedConn = InputService.InputEnded:Connect(function(EndInput)
                        if EndInput == Input or EndInput.UserInputType == Enum.UserInputType.Touch then
                            ChangedConn:Disconnect()
                            EndedConn:Disconnect()
                            Library:AttemptSave()
                        end
                    end)
                end
            end)
        end

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize
                local DFPos, DFSize = DisplayFrame.AbsolutePosition, DisplayFrame.AbsoluteSize
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X or Mouse.Y < DFPos.Y or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    if not (Mouse.X >= DFPos.X and Mouse.X <= DFPos.X + DFSize.X and Mouse.Y >= DFPos.Y and Mouse.Y <= DFPos.Y + DFSize.Y) then
                        ColorPicker:Hide()
                    end
                end
            end
        end))

        function ColorPicker:GetTransparency() return ColorPicker.Transparency end

        local _OrigDisplay = ColorPicker.Display
        ColorPicker.Display = function(self)
            _OrigDisplay(self)
            Library:SafeCallback(ColorPicker.TransparencyChanged, ColorPicker.Transparency)
        end

        ColorPicker:Display()
        Options[Idx] = ColorPicker
        return self
    end

    function Funcs:AddColorPickerAlpha(Idx, Info)
        Info = Info or {}
        if Info.Transparency == nil then Info.Transparency = 0 end
        return Funcs.AddColorPicker(self, Idx, Info)
    end

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self
        local ToggleLabel = self.TextLabel
        assert(Info.Default, 'AddKeyPicker: Missing default.')

        local KeyPicker = {
            Value = Info.Default; Toggled = false;
            Mode = Info.Mode or 'Toggle'; Type = 'KeyPicker';
            Callback = Info.Callback or function() end;
            ChangedCallback = Info.ChangedCallback or function() end;
            SyncToggleState = Info.SyncToggleState or false;
        }
        if KeyPicker.SyncToggleState then Info.Modes = { 'Toggle' }; Info.Mode = 'Toggle' end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0), BorderColor3 = Color3.new(0,0,0),
            Size = UDim2.new(0, 28, 0, 15), ZIndex = 6, Parent = ToggleLabel,
        })
        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor,
            BorderColor3 = Library.OutlineColor, BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 7, Parent = PickOuter,
        })
        Library:AddToRegistry(PickInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0), TextSize = Library.FontSize - 1,
            Text = Info.Default, TextWrapped = true, ZIndex = 8, Parent = PickInner,
        })

        local ModeSelectOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0,0,0),
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1),
            Size = UDim2.new(0, 60, 0, 47), Visible = false, ZIndex = 14, Parent = ScreenGui,
        })
        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1)
        end)
        local ModeSelectInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor,
            BorderColor3 = Library.OutlineColor, BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 15, Parent = ModeSelectOuter,
        })
        Library:ApplyGlass(ModeSelectInner, { Style = 'Background' })
        Library:AddToRegistry(ModeSelectInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })
        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = ModeSelectInner,
        })

        local KeybindEntry = Library:Create('Frame', {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
            Visible = false, ZIndex = 110, Parent = Library.KeybindContainer,
        })
        local ContainerLabel = Library:CreateLabel({
            Position = UDim2.new(0, 2, 0, 0), Size = UDim2.new(1, -4, 1, 0),
            TextSize = Library.FontSize - 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 111, Parent = KeybindEntry,
        }, true)

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' }
        local ModeButtons = {}
        for _, Mode in next, Modes do
            local ModeButton = {}
            local Label = Library:CreateLabel({
                Active = false, Size = UDim2.new(1, 0, 0, 15),
                TextSize = Library.FontSize - 1, Text = Mode,
                ZIndex = 16, Parent = ModeSelectInner,
            })
            function ModeButton:Select()
                for _, b in next, ModeButtons do b:Deselect() end
                KeyPicker.Mode = Mode
                Label.TextColor3 = Library.AccentColor
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor'
                ModeSelectOuter.Visible = false
            end
            function ModeButton:Deselect()
                KeyPicker.Mode = nil
                Label.TextColor3 = Library.FontColor
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor'
            end
            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                    ModeButton:Select()
                    Library:AttemptSave()
                end
            end)
            if Mode == KeyPicker.Mode then ModeButton:Select() end
            ModeButtons[Mode] = ModeButton
        end

        function KeyPicker:Update()
            if Info.NoUI then return end
            local State = KeyPicker:GetState()
            local displayKey = (KeyPicker.Value == 'None') and '...' or KeyPicker.Value
            ContainerLabel.Text = string.format('[%s] %s (%s)', displayKey, Info.Text, KeyPicker.Mode)
            local kbMode = Library.KeybindMode or 'All'
            if kbMode == 'Active' then
                KeybindEntry.Visible = State == true
            elseif kbMode == 'Toggled' then
                local parentOn
                if ParentObj and ParentObj.Type == 'Toggle' then parentOn = ParentObj.Value == true
                elseif KeyPicker.SyncToggleState and ParentObj then parentOn = ParentObj.Value == true
                else parentOn = true end
                KeybindEntry.Visible = parentOn
            else
                KeybindEntry.Visible = true
            end
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor
            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor'
            local YSize, XSize = 0, 0
            for _, Frame in next, Library.KeybindContainer:GetChildren() do
                if Frame:IsA('Frame') and Frame.Visible then
                    YSize = YSize + 18
                    local LabelChild = Frame:FindFirstChildOfClass('TextLabel')
                    if LabelChild and (LabelChild.TextBounds.X + 20 > XSize) then
                        XSize = LabelChild.TextBounds.X + 20
                    end
                end
            end
            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 25, 210), 0, YSize + 23)
        end

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then return true
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then return false end
                local Key = KeyPicker.Value
                if Key == 'MB1' or Key == 'MB2' or Key == 'Touch' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                        or Key == 'Touch' and true
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value])
                end
            end
            return KeyPicker.Toggled
        end

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2]
            DisplayLabel.Text = Key
            KeyPicker.Value = Key
            if ModeButtons[Mode] then ModeButtons[Mode]:Select() end
            KeyPicker:Update()
        end

        function KeyPicker:OnClick(Callback) KeyPicker.Clicked = Callback end
        function KeyPicker:OnChanged(Callback) KeyPicker.Changed = Callback; Callback(KeyPicker.Value) end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
            table.insert(Library.KeyPickerList, KeyPicker)
        end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end
            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false
        PickOuter.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                Picking = true
                DisplayLabel.Text = ''
                local Break, Text = false, ''
                task.spawn(function()
                    while not Break do
                        if Text == '...' then Text = '' end
                        Text = Text .. '.'
                        DisplayLabel.Text = Text
                        wait(0.4)
                    end
                end)
                wait(0.2)
                local Event
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key
                    if Input.UserInputType == Enum.UserInputType.Keyboard then Key = Input.KeyCode.Name
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then Key = 'MB1'
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then Key = 'MB2'
                    elseif Input.UserInputType == Enum.UserInputType.Touch then Key = 'Touch' end
                    Break = true
                    Picking = false
                    DisplayLabel.Text = Key
                    KeyPicker.Value = Key
                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)
                    Library:AttemptSave()
                    Event:Disconnect()
                end)
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = true
            end
        end)

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if not Picking then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value
                    if Key == 'MB1' or Key == 'MB2' or Key == 'Touch' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2
                        or Key == 'Touch' and Input.UserInputType == Enum.UserInputType.Touch then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end
                    end
                end
                KeyPicker:Update()
            end
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X or Mouse.Y < (AbsPos.Y - 21) or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    ModeSelectOuter.Visible = false
                end
            end
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if not Picking then KeyPicker:Update() end
        end))

        KeyPicker:Update()
        Options[Idx] = KeyPicker
        return self
    end

    BaseAddons.__index = Funcs
    BaseAddons.__namecall = function(Table, Key, ...) return Funcs[Key](...) end
end

-- ============================================================
-- BASE GROUPBOX
-- ============================================================
local BaseGroupbox = {}
do
    local Funcs = {}

    function Funcs:AddBlank(Size)
        Library:Create('Frame', {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Size),
            ZIndex = 1, Parent = self.Container,
        })
    end

    function Funcs:AddRow(Columns)
        local Groupbox = self
        local ColumnsCount = type(Columns) == 'number' and math.max(1, Columns) or 2
        local RowOuter = Library:Create('Frame', {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
            ZIndex = 1, Parent = Groupbox.Container,
        })
        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8), Parent = RowOuter,
        })
        local Boxes = {}
        for i = 1, ColumnsCount do
            local Box = { Type = 'Groupbox' }
            local BoxContainer = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Size = UDim2.new(1 / ColumnsCount, -((ColumnsCount - 1) * 8) / ColumnsCount, 1, 0),
                ZIndex = 1, Parent = RowOuter,
            })
            local BoxLayout = Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4), Parent = BoxContainer,
            })
            Box.Container = BoxContainer
            setmetatable(Box, BaseGroupbox)
            function Box:Resize()
                local maxHeight = 0
                for _, child in next, RowOuter:GetChildren() do
                    if child:IsA('Frame') then
                        local layout = child:FindFirstChildOfClass('UIListLayout')
                        if layout and layout.AbsoluteContentSize.Y > maxHeight then
                            maxHeight = layout.AbsoluteContentSize.Y
                        end
                    end
                end
                RowOuter.Size = UDim2.new(1, 0, 0, maxHeight)
                if Groupbox.Resize then Groupbox:Resize() end
            end
            BoxLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Box:Resize() end)
            table.insert(Boxes, Box)
        end
        Groupbox:AddBlank(1)
        if Groupbox.Resize then Groupbox:Resize() end
        return unpack(Boxes)
    end

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {}
        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15), TextSize = Library.FontSize,
            Text = Text, TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 5, Parent = self.Container,
        })
        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, Library.FontSize, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4),
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                SortOrder = Enum.SortOrder.LayoutOrder, Parent = TextLabel,
            })
        end
        Label.TextLabel = TextLabel
        Label.Container = self.Container
        function Label:SetText(NewText)
            TextLabel.Text = NewText
            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(NewText, Library.Font, Library.FontSize, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end
            self.Resize()
        end
        if not DoesWrap then setmetatable(Label, BaseAddons) end
        self:AddBlank(5)
        self:Resize()
        return Label
    end

    function Funcs:AddButton(...)
        local Button = {}
        local function ProcessParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end
            assert(type(Obj.Func) == 'function', 'AddButton: `Func` missing.')
        end
        ProcessParams('Button', Button, ...)

        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0,0,0), BorderColor3 = Color3.new(0,0,0),
                Size = UDim2.new(1, -4, 0, 20), ZIndex = 5,
            })
            local Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor,
                BorderColor3 = Library.OutlineColor, BorderMode = Enum.BorderMode.Inset,
                Size = UDim2.new(1, 0, 1, 0), ZIndex = 6, Parent = Outer,
            })
            Library:ApplyGlass(Inner, { Style = 'Small' })
            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0), TextSize = Library.FontSize,
                Text = Button.Text, ZIndex = 6, Parent = Inner,
            })
            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212,212,212)),
                }),
                Rotation = 90, Parent = Inner,
            })
            Library:AddToRegistry(Outer, { BorderColor3 = 'Black' })
            Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
            Library:OnHighlight(Outer, Outer, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' })
            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then return false end
                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return false end
                return true
            end
            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) or Button.Locked then return end
                Library:SafeCallback(Button.Func)
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = self.Container
        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then Library:AddToolTip(tooltip, self.Outer) end
            return self
        end
        function Button:AddButton(...)
            local Sub = {}
            ProcessParams('SubButton', Sub, ...)
            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)
            Sub.Outer, Sub.Inner, Sub.Label = CreateBaseButton(Sub)
            Sub.Outer.Position = UDim2.new(1, 3, 0, 0)
            Sub.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            Sub.Outer.Parent = self.Outer
            function Sub:AddTooltip(tooltip)
                if type(tooltip) == 'string' then Library:AddToolTip(tooltip, self.Outer) end
                return Sub
            end
            if type(Sub.Tooltip) == 'string' then Sub:AddTooltip(Sub.Tooltip) end
            InitEvents(Sub)
            return Sub
        end
        if type(Button.Tooltip) == 'string' then Button:AddTooltip(Button.Tooltip) end

        self:AddBlank(5)
        self:Resize()
        return Button
    end

    function Funcs:AddDivider()
        self:AddBlank(2)
        local Outer = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0), BorderColor3 = Color3.new(0,0,0),
            Size = UDim2.new(1, -4, 0, 5), ZIndex = 5, Parent = self.Container,
        })
        local Inner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor, BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 6, Parent = Outer,
        })
        Inner.BackgroundTransparency = Library:ComputeGlassTransparency('Small')
        Library:AddToRegistry(Outer, { BorderColor3 = 'Black' })
        Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        self:AddBlank(9)
        self:Resize()
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing Text')
        local Textbox = {
            Value = Info.Default or ''; Numeric = Info.Numeric or false;
            Finished = Info.Finished or false; Type = 'Input';
            Callback = Info.Callback or function() end;
        }
        Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15), TextSize = Library.FontSize,
            Text = Info.Text, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 5, Parent = self.Container,
        })
        self:AddBlank(1)

        local Outer = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0), BorderColor3 = Color3.new(0,0,0),
            Size = UDim2.new(1, -4, 0, 20), ZIndex = 5, Parent = self.Container,
        })
        local Inner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6, Parent = Outer,
        })
        Library:ApplyGlass(Inner, { Style = 'Small' })
        Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        Library:OnHighlight(Outer, Outer, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' })
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, Outer) end

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212,212,212)),
            }),
            Rotation = 90, Parent = Inner,
        })

        local BoxContainer = Library:Create('Frame', {
            BackgroundTransparency = 1, ClipsDescendants = true,
            Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, -5, 1, 0),
            ZIndex = 7, Parent = Inner,
        })
        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1), Font = Library.Font,
            PlaceholderColor3 = Color3.fromRGB(190,190,190),
            PlaceholderText = Info.Placeholder or '', Text = Info.Default or '',
            TextColor3 = Library.FontColor, TextSize = Library.FontSize,
            TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 7, Parent = BoxContainer,
        })
        Library:ApplyTextStroke(Box)

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then Text = Text:sub(1, Info.MaxLength) end
            if Textbox.Numeric and (not tonumber(Text)) and Text:len() > 0 then Text = Textbox.Value end
            Textbox.Value = Text
            Box.Text = Text
            Library:SafeCallback(Textbox.Callback, Textbox.Value)
            Library:SafeCallback(Textbox.Changed, Textbox.Value)
        end

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end
                Textbox:SetValue(Box.Text)
                Library:AttemptSave()
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text)
                Library:AttemptSave()
            end)
        end

        Library:AddToRegistry(Box, { TextColor3 = 'FontColor' })
        function Textbox:OnChanged(Func) Textbox.Changed = Func; Func(Textbox.Value) end

        self:AddBlank(5)
        self:Resize()
        Options[Idx] = Textbox
        return Textbox
    end

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddToggle: Missing Text')
        local Toggle = {
            Value = Info.Default or false; Type = 'Toggle';
            Callback = Info.Callback or function() end;
            Addons = {}; Risky = Info.Risky;
        }
        local Outer = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0), BorderColor3 = Color3.new(0,0,0),
            Size = UDim2.new(0, 13, 0, 13), ZIndex = 5, Parent = self.Container,
        })
        Library:AddToRegistry(Outer, { BorderColor3 = 'Black' })
        local Inner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6, Parent = Outer,
        })
        Library:ApplyGlass(Inner, { Style = 'Small' })
        Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        local Label = Library:CreateLabel({
            Size = UDim2.new(0, 216, 1, 0), Position = UDim2.new(1, 6, 0, 0),
            TextSize = Library.FontSize, Text = Info.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 6, Parent = Inner,
        })
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = Label,
        })
        local Region = Library:Create('Frame', {
            BackgroundTransparency = 1, Size = UDim2.new(0, 170, 1, 0),
            ZIndex = 8, Parent = Outer,
        })
        Library:OnHighlight(Region, Outer, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' })
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, Region) end

        function Toggle:Display()
            Inner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor
            Inner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor
            Library.RegistryMap[Inner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor'
            Library.RegistryMap[Inner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor'
        end
        function Toggle:OnChanged(Func) Toggle.Changed = Func; Func(Toggle.Value) end
        function Toggle:SetValue(Bool)
            Bool = not not Bool
            Toggle.Value = Bool
            Toggle:Display()
            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end
            Library:SafeCallback(Toggle.Callback, Toggle.Value)
            Library:SafeCallback(Toggle.Changed, Toggle.Value)
            Library:UpdateDependencyBoxes()
        end
        Region.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value)
                Library:AttemptSave()
            end
        end)
        if Toggle.Risky then
            Library:RemoveFromRegistry(Label)
            Label.TextColor3 = Library.RiskColor
            Library:AddToRegistry(Label, { TextColor3 = 'RiskColor' })
        end
        Toggle:Display()
        self:AddBlank(Info.BlankSize or 7)
        self:Resize()
        Toggle.TextLabel = Label
        Toggle.Container = self.Container
        setmetatable(Toggle, BaseAddons)
        Toggles[Idx] = Toggle
        Library:UpdateDependencyBoxes()
        return Toggle
    end

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default and Info.Text and Info.Min and Info.Max, 'AddSlider: missing fields')
        if not Info.Rounding then Info.Rounding = 0 end
        local Slider = {
            Value = Info.Default; Min = Info.Min; Max = Info.Max;
            Rounding = Info.Rounding; MaxSize = 232; Type = 'Slider';
            Callback = Info.Callback or function() end;
        }
        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10), TextSize = Library.FontSize,
                Text = Info.Text, TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Bottom,
                ZIndex = 5, Parent = self.Container,
            })
            self:AddBlank(3)
        end
        local Outer = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0), BorderColor3 = Color3.new(0,0,0),
            Size = UDim2.new(1, -4, 0, 13), ZIndex = 5, Parent = self.Container,
        })
        Library:AddToRegistry(Outer, { BorderColor3 = 'Black' })
        local Inner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6, Parent = Outer,
        })
        Library:ApplyGlass(Inner, { Style = 'Small' })
        Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor, BorderColor3 = Library.AccentColorDark,
            Size = UDim2.new(0, 0, 1, 0), ZIndex = 7, Parent = Inner,
        })
        Fill.BackgroundTransparency = 0.15
        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor'; BorderColor3 = 'AccentColorDark' })
        local HideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0,
            Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0),
            ZIndex = 8, Parent = Fill,
        })
        Library:AddToRegistry(HideBorderRight, { BackgroundColor3 = 'AccentColor' })
        local Label = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0), TextSize = Library.FontSize,
            Text = 'Infinite', ZIndex = 9, Parent = Inner,
        })
        Library:OnHighlight(Outer, Outer, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' })
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, Outer) end

        function Slider:Display()
            local suffix = Info.Suffix or ''
            if Info.Compact then
                Label.Text = Info.Text .. ': ' .. Slider.Value .. suffix
            elseif Info.HideMax then
                Label.Text = tostring(Slider.Value) .. suffix
            else
                Label.Text = Slider.Value .. suffix .. '/' .. Slider.Max .. suffix
            end
            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize))
            Fill.Size = UDim2.new(0, X, 1, 0)
            HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0)
        end
        function Slider:OnChanged(Func) Slider.Changed = Func; Func(Slider.Value) end
        local function Round(v)
            if Slider.Rounding == 0 then return math.floor(v) end
            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', v))
        end
        function Slider:GetValueFromXOffset(X) return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max)) end
        function Slider:SetValue(Str)
            local Num = tonumber(Str)
            if not Num then return end
            Num = math.clamp(Num, Slider.Min, Slider.Max)
            Slider.Value = Num
            Slider:Display()
            Library:SafeCallback(Slider.Callback, Slider.Value)
            Library:SafeCallback(Slider.Changed, Slider.Value)
        end
        Inner.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                local function Update(PosX)
                    local Diff = PosX - Fill.AbsolutePosition.X
                    local nX = math.clamp(Diff, 0, Slider.MaxSize)
                    local nVal = Slider:GetValueFromXOffset(nX)
                    local old = Slider.Value
                    Slider.Value = nVal
                    Slider:Display()
                    if nVal ~= old then
                        Library:SafeCallback(Slider.Callback, Slider.Value)
                        Library:SafeCallback(Slider.Changed, Slider.Value)
                    end
                end
                Update(Input.Position.X)
                local ChangedConn = InputService.InputChanged:Connect(function(C)
                    if C.UserInputType == Enum.UserInputType.MouseMovement or C == Input then Update(C.Position.X) end
                end)
                local EndedConn
                EndedConn = InputService.InputEnded:Connect(function(E)
                    if E == Input or E.UserInputType == Enum.UserInputType.Touch then
                        ChangedConn:Disconnect()
                        EndedConn:Disconnect()
                        Library:AttemptSave()
                    end
                end)
            end
        end)
        Slider:Display()
        self:AddBlank(Info.BlankSize or 6)
        self:Resize()
        Options[Idx] = Slider
        return Slider
    end

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then Info.Values = GetPlayersString(); Info.AllowNull = true end
        if Info.SpecialType == 'Team' then Info.Values = GetTeamsString(); Info.AllowNull = true end
        assert(Info.Values, 'AddDropdown: Missing values')
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default')
        if not Info.Text then Info.Compact = true end
        local Dropdown = {
            Values = Info.Values; Value = Info.Multi and {} or nil;
            Multi = Info.Multi; Type = 'Dropdown'; SpecialType = Info.SpecialType;
            Callback = Info.Callback or function() end;
        }
        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10), TextSize = Library.FontSize,
                Text = Info.Text, TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Bottom,
                ZIndex = 5, Parent = self.Container,
            })
            self:AddBlank(3)
        end
        local Outer = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0), BorderColor3 = Color3.new(0,0,0),
            Size = UDim2.new(1, -4, 0, 20), ZIndex = 5, Parent = self.Container,
        })
        Library:AddToRegistry(Outer, { BorderColor3 = 'Black' })
        local Inner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6, Parent = Outer,
        })
        Library:ApplyGlass(Inner, { Style = 'Small' })
        Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212,212,212)),
            }),
            Rotation = 90, Parent = Inner,
        })
        local Arrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -16, 0.5, 0),
            Size = UDim2.new(0, 12, 0, 12),
            Image = 'http://www.roblox.com/asset/?id=6282522798',
            ZIndex = 8, Parent = Inner,
        })
        local ItemLabel = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, -5, 1, 0),
            TextSize = Library.FontSize, Text = '--',
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true, ZIndex = 7, Parent = Inner,
        })
        Library:OnHighlight(Outer, Outer, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' })
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, Outer) end

        local MAX_DROPDOWN_ITEMS = 8
        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0), BorderColor3 = Color3.new(0,0,0),
            ZIndex = 20, Visible = false, Parent = ScreenGui,
        })
        local function RecalcListPosition()
            ListOuter.Position = UDim2.fromOffset(Outer.AbsolutePosition.X, Outer.AbsolutePosition.Y + Outer.Size.Y.Offset + 1)
        end
        local function RecalcListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(Outer.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end
        RecalcListPosition()
        RecalcListSize()
        Outer:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalcListPosition)

        local ListInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 21, Parent = ListOuter,
        })
        Library:ApplyGlass(ListInner, { Style = 'Background' })
        Library:AddToRegistry(ListInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1, BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 21, Parent = ListInner,
            ScrollBarThickness = 3, ScrollBarImageColor3 = Library.AccentColor,
        })
        Library:AddToRegistry(Scrolling, { ScrollBarImageColor3 = 'AccentColor' })
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0),
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = Scrolling,
        })

        function Dropdown:Display()
            local str = ''
            if Info.Multi then
                for _, Value in next, Dropdown.Values do
                    if Dropdown.Value[Value] then str = str .. Value .. ', ' end
                end
                str = str:sub(1, #str - 2)
            else
                str = Dropdown.Value or ''
            end
            ItemLabel.Text = (str == '' and '--' or str)
        end
        function Dropdown:GetActiveValues()
            if Info.Multi then
                local t = {}
                for Value in next, Dropdown.Value do table.insert(t, Value) end
                return t
            end
            return Dropdown.Value and 1 or 0
        end
        function Dropdown:BuildDropdownList()
            local Buttons = {}
            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then Element:Destroy() end
            end
            local Count = 0
            for _, Value in next, Dropdown.Values do
                local Table = {}
                Count = Count + 1
                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
                    BorderMode = Enum.BorderMode.Middle, Size = UDim2.new(1, -1, 0, 20),
                    ZIndex = 23, Active = true, Parent = Scrolling,
                })
                Button.BackgroundTransparency = 0.15
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
                local ButtonLabel = Library:CreateLabel({
                    Active = false, Size = UDim2.new(1, -6, 1, 0),
                    Position = UDim2.new(0, 6, 0, 0),
                    TextSize = Library.FontSize, Text = Value,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 25, Parent = Button,
                })
                Library:OnHighlight(Button, Button, { BorderColor3 = 'AccentColor', ZIndex = 24 }, { BorderColor3 = 'OutlineColor', ZIndex = 23 })
                local Selected
                if Info.Multi then Selected = Dropdown.Value[Value]
                else Selected = Dropdown.Value == Value end
                function Table:UpdateButton()
                    if Info.Multi then Selected = Dropdown.Value[Value]
                    else Selected = Dropdown.Value == Value end
                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor'
                end
                ButtonLabel.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        local Try = not Selected
                        if Dropdown:GetActiveValues() == 1 and not Try and not Info.AllowNull then
                        else
                            if Info.Multi then
                                Selected = Try
                                if Selected then Dropdown.Value[Value] = true else Dropdown.Value[Value] = nil end
                            else
                                Selected = Try
                                if Selected then Dropdown.Value = Value else Dropdown.Value = nil end
                                for _, OtherButton in next, Buttons do OtherButton:UpdateButton() end
                            end
                            Table:UpdateButton()
                            Dropdown:Display()
                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
                            Library:AttemptSave()
                        end
                    end
                end)
                Table:UpdateButton()
                Dropdown:Display()
                Buttons[Button] = Table
            end
            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1)
            RecalcListSize(math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1)
        end
        function Dropdown:SetValues(newValues)
            if newValues then Dropdown.Values = newValues end
            Dropdown:BuildDropdownList()
        end
        function Dropdown:OpenDropdown()
            ListOuter.Visible = true
            Library.OpenedFrames[ListOuter] = true
            Arrow.Rotation = 180
        end
        function Dropdown:CloseDropdown()
            ListOuter.Visible = false
            Library.OpenedFrames[ListOuter] = nil
            Arrow.Rotation = 0
        end
        function Dropdown:OnChanged(Func) Dropdown.Changed = Func; Func(Dropdown.Value) end
        function Dropdown:SetValue(Val)
            if Info.Multi then
                local nTable = {}
                for Value in next, Val do
                    if table.find(Dropdown.Values, Value) then nTable[Value] = true end
                end
                Dropdown.Value = nTable
            else
                if not Val then Dropdown.Value = nil
                elseif table.find(Dropdown.Values, Val) then Dropdown.Value = Val end
            end
            Dropdown:BuildDropdownList()
            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
        end
        Outer.InputBegan:Connect(function(Input)
            if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then Dropdown:CloseDropdown() else Dropdown:OpenDropdown() end
            end
        end)
        InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X or Mouse.Y < (AbsPos.Y - 21) or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    Dropdown:CloseDropdown()
                end
            end
        end)
        Dropdown:BuildDropdownList()
        Dropdown:Display()

        local Defaults = {}
        if type(Info.Default) == 'string' then
            local i = table.find(Dropdown.Values, Info.Default)
            if i then table.insert(Defaults, i) end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local i = table.find(Dropdown.Values, Value)
                if i then table.insert(Defaults, i) end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] then
            table.insert(Defaults, Info.Default)
        end
        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then Dropdown.Value[Dropdown.Values[Index]] = true
                else Dropdown.Value = Dropdown.Values[Index] end
                if not Info.Multi then break end
            end
            Dropdown:BuildDropdownList()
            Dropdown:Display()
        end
        self:AddBlank(Info.BlankSize or 5)
        self:Resize()
        Options[Idx] = Dropdown
        return Dropdown
    end

    function Funcs:AddDependencyBox()
        local Depbox = { Dependencies = {} }
        local Groupbox = self
        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
            Visible = false, Parent = Groupbox.Container,
        })
        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
            Visible = true, Parent = Holder,
        })
        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = Frame,
        })
        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y)
            Groupbox:Resize()
        end
        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Depbox:Resize() end)
        Holder:GetPropertyChangedSignal('Visible'):Connect(function() Depbox:Resize() end)
        function Depbox:Update()
            for _, Dep in next, Depbox.Dependencies do
                local Elem, Value = Dep[1], Dep[2]
                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false
                    Depbox:Resize()
                    return
                end
            end
            Holder.Visible = true
            Depbox:Resize()
        end
        function Depbox:SetupDependencies(Deps)
            Depbox.Dependencies = Deps
            Depbox:Update()
        end
        Depbox.Container = Frame
        setmetatable(Depbox, BaseGroupbox)
        table.insert(Library.DependencyBoxes, Depbox)
        return Depbox
    end

    BaseGroupbox.__index = Funcs
    BaseGroupbox.__namecall = function(Table, Key, ...) return Funcs[Key](...) end
end

-- ============================================================
-- NOTIFICATIONS / WATERMARK / KEYBINDS
-- ============================================================
Library.NotificationArea = Library:Create('Frame', {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, Library.NotifyConfig.PositionX, 0, Library.NotifyConfig.PositionY),
    Size = UDim2.new(0, 300, 1, -Library.NotifyConfig.PositionY),
    ZIndex = 100, Parent = ScreenGui,
})
Library.NotifLayout = Library:Create('UIListLayout', {
    Padding = UDim.new(0, 4), FillDirection = Enum.FillDirection.Vertical,
    SortOrder = Enum.SortOrder.LayoutOrder, Parent = Library.NotificationArea,
})

local WatermarkOuter = Library:Create('Frame', {
    AnchorPoint = Vector2.new(0.5, 0), BorderColor3 = Color3.new(0,0,0),
    Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0, 213, 0, 20),
    ZIndex = 200, Visible = false, Parent = ScreenGui,
})
local WatermarkInner = Library:Create('Frame', {
    BackgroundColor3 = Library.MainColor, BorderColor3 = Library.AccentColor,
    BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
    ZIndex = 201, Parent = WatermarkOuter,
})
Library:AddToRegistry(WatermarkInner, { BorderColor3 = 'AccentColor' })
local WMInner = Library:Create('Frame', {
    BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0,
    Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(1, -2, 1, -2),
    ZIndex = 202, Parent = WatermarkInner,
})
Library:ApplyGlass(WMInner, { Style = 'Panel' })

local WatermarkLabel = Library:CreateLabel({
    Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, -4, 1, 0),
    TextSize = Library.FontSize, TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 203, Parent = WMInner,
})
Library.Watermark = WatermarkOuter
Library.WatermarkText = WatermarkLabel
Library:MakeDraggable(Library.Watermark)

local KeybindOuter = Library:Create('Frame', {
    AnchorPoint = Vector2.new(0, 0.5), BorderColor3 = Color3.new(0,0,0),
    Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.new(0, 210, 0, 20),
    Visible = false, ZIndex = 100, Parent = ScreenGui,
})
local KeybindInner = Library:Create('Frame', {
    BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
    BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
    ZIndex = 101, Parent = KeybindOuter,
})
Library:ApplyGlass(KeybindInner, { Style = 'Panel' })
Library:AddToRegistry(KeybindInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' }, true)
local ColorFrame = Library:Create('Frame', {
    BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 2), ZIndex = 102, Parent = KeybindInner,
})
Library:AddToRegistry(ColorFrame, { BackgroundColor3 = 'AccentColor' }, true)
Library:CreateLabel({
    Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(5, 2),
    TextXAlignment = Enum.TextXAlignment.Left, Text = 'Keybinds',
    ZIndex = 104, Parent = KeybindInner,
})
local KeybindContainer = Library:Create('Frame', {
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -20),
    Position = UDim2.new(0, 0, 0, 20), ZIndex = 1, Parent = KeybindInner,
})
Library:Create('UIListLayout', {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder = Enum.SortOrder.LayoutOrder, Parent = KeybindContainer,
})
Library:Create('UIPadding', { PaddingLeft = UDim.new(0, 5), Parent = KeybindContainer })
Library.KeybindFrame = KeybindOuter
Library.KeybindContainer = KeybindContainer
Library:MakeDraggable(KeybindOuter)

function Library:SetKeybindMode(Mode)
    Library.KeybindMode = Mode
    for _, kp in ipairs(Library.KeyPickerList) do
        if not kp.NoUI then pcall(function() kp:Update() end) end
    end
end

function Library:SetWatermarkVisibility(bool) Library.Watermark.Visible = bool end
function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, Library.FontSize)
    local posY = Library.Watermark.Position.Y
    Library.Watermark.AnchorPoint = Vector2.new(0.5, 0)
    Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3)
    Library.Watermark.Position = UDim2.new(0.5, 0, posY.Scale, posY.Offset)
    Library:SetWatermarkVisibility(true)
    Library.WatermarkText.Text = Text
end

function Library:Notify(Text, Time)
    local cfg = Library.NotifyConfig
    local barSide = cfg.BarSide or 'Left'
    local align = cfg.Alignment or 'Left'

    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, Library.FontSize)
    YSize = YSize + 7
    local BAR_THIN, BAR_THICK = 3, 3
    local innerPosX = 1
    local innerPosY = (barSide == 'Top') and BAR_THICK or 1
    local innerSizeW = -2
    local innerSizeH = (barSide == 'Top' or barSide == 'Bottom') and -(BAR_THICK + 1) or -2
    local labelPosX = (barSide == 'Left') and BAR_THIN + 2 or 4
    local labelSizeW = (barSide == 'Left' or barSide == 'Right') and -(BAR_THIN + 4) or -4

    local outerAnchor = Vector2.new(0, 0)
    if align == 'Center' then outerAnchor = Vector2.new(0.5, 0)
    elseif align == 'Right' then outerAnchor = Vector2.new(1, 0) end

    local position
    if align == 'Center' then position = UDim2.new(0.5, 0, 0, 0)
    elseif align == 'Right' then position = UDim2.new(1, 0, 0, 0)
    else position = UDim2.new(0, 0, 0, 0) end

    local NotifyOuter = Library:Create('Frame', {
        BackgroundTransparency = 1, AnchorPoint = outerAnchor,
        BorderColor3 = Color3.new(0,0,0), Position = position,
        Size = UDim2.new(0, 0, 0, YSize), ClipsDescendants = true,
        ZIndex = 100, Parent = Library.NotificationArea,
    })
    local NotifyInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
        BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 101, Parent = NotifyOuter,
    })
    Library:ApplyGlass(NotifyInner, { Style = 'Panel' })
    Library:AddToRegistry(NotifyInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' }, true)
    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0,
        Position = UDim2.new(0, innerPosX, 0, innerPosY),
        Size = UDim2.new(1, innerSizeW, 1, innerSizeH),
        ZIndex = 102, Parent = NotifyInner,
    })
    Library:ApplyGlass(InnerFrame, { Style = 'Panel' })

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, labelPosX, 0, 0),
        Size = UDim2.new(1, labelSizeW, 1, 0), Text = Text,
        TextXAlignment = (align == 'Center') and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
        TextSize = Library.FontSize, ZIndex = 103, Parent = InnerFrame,
    })
    local AccentBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0,
        ZIndex = 104, Parent = NotifyOuter,
    })
    if barSide == 'Left' then
        AccentBar.Position = UDim2.new(0, -1, 0, -1)
        AccentBar.Size = UDim2.new(0, BAR_THIN, 1, 2)
    elseif barSide == 'Right' then
        AccentBar.Position = UDim2.new(1, -BAR_THIN + 1, 0, -1)
        AccentBar.Size = UDim2.new(0, BAR_THIN, 1, 2)
    elseif barSide == 'Top' then
        AccentBar.Position = UDim2.new(0, -1, 0, -1)
        AccentBar.Size = UDim2.new(1, 2, 0, BAR_THICK)
    elseif barSide == 'Bottom' then
        AccentBar.Position = UDim2.new(0, -1, 1, -BAR_THICK + 1)
        AccentBar.Size = UDim2.new(1, 2, 0, BAR_THICK)
    end
    Library:AddToRegistry(AccentBar, { BackgroundColor3 = 'AccentColor' }, true)

    local finalWidth = XSize + 8 + 4
    if barSide == 'Left' or barSide == 'Right' then finalWidth = finalWidth + BAR_THIN end

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, finalWidth, 0, YSize), 'Out', 'Quad', 0.4, true)
    task.spawn(function()
        wait(Time or 5)
        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quad', 0.4, true)
        wait(0.4)
        NotifyOuter:Destroy()
    end)
end

-- ============================================================
-- CREATE WINDOW
-- ============================================================
function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }
    if type(...) == 'table' then
        Config = ...
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false
    end
    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550, 600) end
    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if InputService.TouchEnabled then
        local vp = workspace.CurrentCamera.ViewportSize
        Config.Size = UDim2.fromOffset(math.min(Config.Size.X.Offset, vp.X - 20), math.min(Config.Size.Y.Offset, vp.Y - 60))
    end
    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end
    if Config.WireframeDrag ~= nil then Library.WireframeDrag = Config.WireframeDrag end

    local Window = { Tabs = {} }
    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint, BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = Config.Position, Size = Config.Size, Visible = false, ZIndex = 1, Parent = ScreenGui,
    })
    Library:MakeDraggable(Outer, 25, true)
    if Config.Resizable then Library:MakeResizable(Outer, Config.MinSize, Config.MaxSize) end

    local Inner = Library:Create('Frame', {
        Name = "Inner", BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor, BorderMode = Enum.BorderMode.Inset,
        Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(1, -2, 1, -2),
        ZIndex = 1, Parent = Outer,
    })
    Library:ApplyGlass(Inner, { Style = 'Panel' })
    Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 25),
        Text = Config.Title or '', RichText = true,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 1, Parent = Inner,
    })
    local MapNameLabel = Library:CreateLabel({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -7, 0, 0), Size = UDim2.new(0, 0, 0, 25),
        Text = 'Loading...', TextColor3 = Library.AccentColor,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 1, Parent = Inner,
    })
    Library:AddToRegistry(MapNameLabel, { TextColor3 = 'AccentColor' })
    task.spawn(function()
        local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
        MapNameLabel.Text = ok and info and info.Name or (game.Name or "Unknown Map")
    end)

    local TabBarOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor,
        Position = UDim2.new(0, 8, 0, 25), Size = UDim2.new(1, -16, 0, 29),
        ZIndex = 1, Parent = Inner,
    })
    Library:ApplyGlass(TabBarOuter, { Style = 'Background' })
    Library:AddToRegistry(TabBarOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })
    local TabBarInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Color3.new(0,0,0),
        BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 1, Parent = TabBarOuter,
    })
    Library:ApplyGlass(TabBarInner, { Style = 'Background' })
    Library:AddToRegistry(TabBarInner, { BackgroundColor3 = 'BackgroundColor' })
    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(1, -8, 1, -8),
        ZIndex = 1, Parent = TabBarInner,
    })
    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding or 0),
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = TabArea,
    })

    local MainSectionOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor,
        Position = UDim2.new(0, 8, 0, 58), Size = UDim2.new(1, -16, 1, -66),
        ZIndex = 1, Parent = Inner,
    })
    Library:ApplyGlass(MainSectionOuter, { Style = 'Background' })
    Library:AddToRegistry(MainSectionOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })
    local MainSectionInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Color3.new(0,0,0),
        BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 1, Parent = MainSectionOuter,
    })
    Library:ApplyGlass(MainSectionInner, { Style = 'Background' })
    Library:AddToRegistry(MainSectionInner, { BackgroundColor3 = 'BackgroundColor' })
    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
        Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(1, -16, 1, -16),
        ZIndex = 2, Parent = MainSectionInner,
    })
    Library:ApplyGlass(TabContainer, { Style = 'Panel' })
    Library:AddToRegistry(TabContainer, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })

    function Window:SetWindowTitle(Title) WindowLabel.Text = Title end
    function Window:AddTab(Name)
        local Tab = { Groupboxes = {}, Tabboxes = {} }
        local btnWidth = Library:GetTextBounds(Name, Library.Font, Library.FontSize + 2)
        local TabButton = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor,
            Size = UDim2.new(0, btnWidth + 8 + 4, 1, 0),
            ZIndex = 1, Parent = TabArea,
        })
        Library:ApplyGlass(TabButton, { Style = 'Small' })
        Library:AddToRegistry(TabButton, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })
        Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 1, -1),
            Text = Name, ZIndex = 1, Parent = TabButton,
        })
        local TabIndicator = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 2),
            Visible = false, ZIndex = 4, Parent = TabButton,
        })
        Library:AddToRegistry(TabIndicator, { BackgroundColor3 = 'AccentColor' })

        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame', BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0), Visible = false, ZIndex = 2, Parent = TabContainer,
        })
        local LeftSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.new(0, 7, 0, 7), Size = UDim2.new(0.5, -10, 1, -16),
            CanvasSize = UDim2.new(0, 0, 0, 0), BottomImage = '', TopImage = '',
            ScrollBarThickness = 0, ZIndex = 2, Parent = TabFrame,
        })
        local RightSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.new(0.5, 5, 0, 7), Size = UDim2.new(0.5, -10, 1, -16),
            CanvasSize = UDim2.new(0, 0, 0, 0), BottomImage = '', TopImage = '',
            ScrollBarThickness = 0, ZIndex = 2, Parent = TabFrame,
        })
        for _, Side in next, { LeftSide, RightSide } do
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 8),
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                Parent = Side,
            })
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y)
            end)
        end

        function Tab:ShowTab()
            for _, t in next, Window.Tabs do t:HideTab() end
            TabButton.BackgroundColor3 = Library.MainColor
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor'
            TabFrame.Visible = true
            TabIndicator.Visible = true
        end
        function Tab:HideTab()
            TabButton.BackgroundColor3 = Library.BackgroundColor
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor'
            TabFrame.Visible = false
            TabIndicator.Visible = false
        end
        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position
            TabListLayout:ApplyLayout()
        end
        function Tab:AddGroupbox(Info)
            local Groupbox = {}
            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor,
                BorderColor3 = Library.OutlineColor,
                BorderMode = Enum.BorderMode.Inset,
                Size = UDim2.new(1, 0, 0, 30), ZIndex = 2,
                Parent = Info.Side == 1 and LeftSide or RightSide,
            })
            Library:ApplyGlass(BoxOuter, { Style = 'Background' })
            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })
            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Color3.new(0,0,0),
                Size = UDim2.new(1, -2, 1, -2), Position = UDim2.new(0, 1, 0, 1),
                ZIndex = 4, Parent = BoxOuter,
            })
            Library:ApplyGlass(BoxInner, { Style = 'Background' })
            Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor' })
            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 2), ZIndex = 5, Parent = BoxInner,
            })
            Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor' })
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 4, 0, 2),
                TextSize = Library.FontSize, Text = Info.Name,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 5, Parent = BoxInner,
            })
            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 4, 0, 20), Size = UDim2.new(1, -4, 1, -20),
                ZIndex = 1, Parent = BoxInner,
            })
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder, Parent = Container,
            })
            function Groupbox:Resize()
                local Size = 0
                for _, Element in next, Container:GetChildren() do
                    if not Element:IsA('UIListLayout') and Element.Visible then
                        Size = Size + Element.Size.Y.Offset
                    end
                end
                BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 4)
            end
            Groupbox.Container = Container
            setmetatable(Groupbox, BaseGroupbox)
            Groupbox:AddBlank(3)
            Groupbox:Resize()
            Tab.Groupboxes[Info.Name] = Groupbox
            return Groupbox
        end
        function Tab:AddLeftGroupbox(Name) return Tab:AddGroupbox({ Side = 1; Name = Name }) end
        function Tab:AddRightGroupbox(Name) return Tab:AddGroupbox({ Side = 2; Name = Name }) end

        function Tab:AddTabbox(Info)
            local Tabbox = { Tabs = {} }
            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor,
                BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 0, 30),
                ZIndex = 2, Parent = Info.Side == 1 and LeftSide or RightSide,
            })
            Library:ApplyGlass(BoxOuter, { Style = 'Background' })
            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })
            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Color3.new(0,0,0),
                Size = UDim2.new(1, -2, 1, -2), Position = UDim2.new(0, 1, 0, 1),
                ZIndex = 4, Parent = BoxOuter,
            })
            Library:ApplyGlass(BoxInner, { Style = 'Background' })
            Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor' })
            local BtnBar = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 1), Size = UDim2.new(1, 0, 0, 18),
                ZIndex = 5, Parent = BoxInner,
            })
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                SortOrder = Enum.SortOrder.LayoutOrder, Parent = BtnBar,
            })
            function Tabbox:AddTab(Name)
                local Tab = {}
                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor, BorderColor3 = Color3.new(0,0,0),
                    Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 6, Parent = BtnBar,
                })
                Library:ApplyGlass(Button, { Style = 'Small' })
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor' })
                local TabHighlight = Library:Create('Frame', {
                    BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 2), Visible = false,
                    ZIndex = 10, Parent = Button,
                })
                Library:AddToRegistry(TabHighlight, { BackgroundColor3 = 'AccentColor' })
                Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0), TextSize = Library.FontSize,
                    Text = Name, ZIndex = 7, Parent = Button,
                })
                local Block = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor, BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1),
                    Visible = false, ZIndex = 9, Parent = Button,
                })
                Library:AddToRegistry(Block, { BackgroundColor3 = 'BackgroundColor' })
                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 4, 0, 20), Size = UDim2.new(1, -4, 1, -20),
                    ZIndex = 1, Visible = false, Parent = BoxInner,
                })
                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical,
                    SortOrder = Enum.SortOrder.LayoutOrder, Parent = Container,
                })
                function Tab:Show()
                    for _, t in next, Tabbox.Tabs do t:Hide() end
                    Container.Visible = true
                    Block.Visible = true
                    TabHighlight.Visible = true
                    Button.BackgroundColor3 = Library.BackgroundColor
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor'
                    Tab:Resize()
                end
                function Tab:Hide()
                    Container.Visible = false
                    Block.Visible = false
                    TabHighlight.Visible = false
                    Button.BackgroundColor3 = Library.MainColor
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor'
                end
                function Tab:Resize()
                    local Count = 0
                    for _ in next, Tabbox.Tabs do Count = Count + 1 end
                    for _, b in next, BtnBar:GetChildren() do
                        if not b:IsA('UIListLayout') then
                            b.Size = UDim2.new(1 / Count, 0, 1, 0)
                        end
                    end
                    if not Container.Visible then return end
                    local Size = 0
                    for _, Element in next, Container:GetChildren() do
                        if not Element:IsA('UIListLayout') and Element.Visible then
                            Size = Size + Element.Size.Y.Offset
                        end
                    end
                    BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 4)
                end
                Button.InputBegan:Connect(function(Input)
                    if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and not Library:MouseIsOverOpenedFrame() then
                        Tab:Show()
                        Tab:Resize()
                    end
                end)
                Tab.Container = Container
                Tabbox.Tabs[Name] = Tab
                setmetatable(Tab, BaseGroupbox)
                Tab:AddBlank(3)
                Tab:Resize()
                if #BtnBar:GetChildren() == 2 then Tab:Show() end
                return Tab
            end
            Tab.Tabboxes[Info.Name or ''] = Tabbox
            return Tabbox
        end
        function Tab:AddLeftTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 1 }) end
        function Tab:AddRightTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 2 }) end

        TabButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                Tab:ShowTab()
            end
        end)
        if #TabContainer:GetChildren() == 1 then Tab:ShowTab() end
        Window.Tabs[Name] = Tab
        return Tab
    end

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 0),
        Visible = true, Text = '', Modal = false, Parent = ScreenGui,
    })
    function Library:Toggle()
        Library.Toggled = not Library.Toggled
        ModalElement.Modal = Library.Toggled
        Outer.Visible = Library.Toggled
        if Library.Toggled then
            task.spawn(function()
                local State = InputService.MouseIconEnabled
                local Cursor = Drawing.new('Triangle')
                Cursor.Thickness, Cursor.Filled, Cursor.Visible = 1, true, true
                local Outline = Drawing.new('Triangle')
                Outline.Thickness, Outline.Filled, Outline.Color, Outline.Visible = 1, false, Color3.new(0,0,0), true
                while Library.Toggled and ScreenGui.Parent do
                    InputService.MouseIconEnabled = false
                    local mPos = InputService:GetMouseLocation()
                    Cursor.Color = Library.AccentColor
                    Cursor.PointA = Vector2.new(mPos.X, mPos.Y)
                    Cursor.PointB = Vector2.new(mPos.X + 16, mPos.Y + 6)
                    Cursor.PointC = Vector2.new(mPos.X + 6, mPos.Y + 16)
                    Outline.PointA, Outline.PointB, Outline.PointC = Cursor.PointA, Cursor.PointB, Cursor.PointC
                    RenderStepped:Wait()
                end
                InputService.MouseIconEnabled = State
                Cursor:Remove()
                Outline:Remove()
            end)
        end
        Library:UpdateBlur()
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and not Processed) then
            task.spawn(Library.Toggle)
        end
    end))
    if Config.AutoShow then task.spawn(Library.Toggle) end
    Window.Holder = Outer
    return Window
end

-- Player change handling
local function OnPlayerChange()
    local list = GetPlayersString()
    for _, opt in next, Options do
        if opt.Type == 'Dropdown' and opt.SpecialType == 'Player' then
            opt:SetValues(list)
        end
    end
end
Players.PlayerAdded:Connect(OnPlayerChange)
Players.PlayerRemoving:Connect(OnPlayerChange)

-- Mobile UI
if InputService.TouchEnabled then
    local MobileGui = Instance.new("ScreenGui")
    MobileGui.Name = "LinoriaMobileUI"
    MobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    ProtectGui(MobileGui)
    MobileGui.Parent = CoreGui

    local BTN_W, BTN_H = 88, 30
    local BTN_GAP = 40
    local function CreateMobileButton(name, text, startPos)
        local Outer = Library:Create('Frame', {
            Name = name .. "Outer", BackgroundColor3 = Library.OutlineColor,
            BorderSizePixel = 0, Position = startPos,
            Size = UDim2.new(0, BTN_W, 0, BTN_H), ZIndex = 300,
            Parent = MobileGui, Active = true,
        })
        Library:ApplyGlass(Outer, { Style = 'Outer' })
        Library:AddToRegistry(Outer, { BackgroundColor3 = 'OutlineColor' })
        local Accent = Library:Create('Frame', {
            Name = name .. "Accent", BackgroundColor3 = Library.AccentColor,
            BorderSizePixel = 0, Position = UDim2.new(0, 1, 0, 1),
            Size = UDim2.new(1, -2, 1, -2), ZIndex = 301, Parent = Outer,
        })
        Library:AddToRegistry(Accent, { BackgroundColor3 = 'AccentColor' })
        local Inner = Library:Create('Frame', {
            Name = name .. "Inner", BackgroundColor3 = Library.MainColor,
            BorderSizePixel = 0, Position = UDim2.new(0, 1, 0, 1),
            Size = UDim2.new(1, -2, 1, -2), ZIndex = 302, Parent = Accent,
        })
        Library:ApplyGlass(Inner, { Style = 'Panel' })
        local Btn = Library:Create('TextButton', {
            Name = name .. "Btn", BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.Code,
            Text = text, TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = Library.FontSize - 1, ZIndex = 304, Parent = Inner, Active = true,
        })
        return Outer, Btn
    end
    local ToggleOuter, ToggleBtn = CreateMobileButton("Toggle", "Toggle UI", UDim2.new(0, 10, 0, 10))
    local LockOuter, LockBtn = CreateMobileButton("Lock", "Unlock UI", UDim2.new(0, 10, 0, 10 + BTN_H + (BTN_GAP - BTN_H)))
    local IsUnlocked = false
    local function Bind(Btn, Outer, ClickAction)
        local dragging, dragInput, dragStart, startPos, hasMoved = false, nil, nil, nil, false
        Btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; hasMoved = false
                dragStart = input.Position; startPos = Outer.Position; dragInput = input
                local conn
                conn = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false; conn:Disconnect()
                        if not hasMoved then ClickAction() end
                    end
                end)
            end
        end)
        InputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                if delta.Magnitude > 3 then hasMoved = true end
                if IsUnlocked and hasMoved then
                    Outer.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end
        end)
    end
    Bind(ToggleBtn, ToggleOuter, function() Library:Toggle() end)
    Bind(LockBtn, LockOuter, function()
        IsUnlocked = not IsUnlocked
        LockBtn.Text = IsUnlocked and "Lock UI" or "Unlock UI"
        LockBtn.TextColor3 = IsUnlocked and Library.AccentColor or Color3.fromRGB(255,255,255)
    end)
end

getgenv().Library = Library
return Library
