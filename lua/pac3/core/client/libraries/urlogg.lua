-- made by Morten and CapsAdmin

local webaudio = pac.webaudio or {}

webaudio.preinit = false
webaudio.debug = 0
webaudio.initialized = false
webaudio.rate = 0
webaudio.SpeedOfSound = 6

webaudio.js_queue = {}
webaudio.streams = {}

local function dprint(str)

    if webaudio.debug == 0 then return end

    if webaudio.debug >= 1 then
        if epoe then
            epoe.MsgC(Color(0, 255, 0), "[WebAudio] ")
            epoe.MsgC(Color(255, 255, 255), str)
            epoe.Print("")
        end

        MsgC(Color(0, 255, 0), "[WebAudio] ")
        MsgC(Color(255, 255, 255), str)
        Msg("\b")
    end

    if webaudio.debug >= 2 then
        easylua.PrintOnServer("[WebAudio] " .. str)
    end
end

do -- STREAM
    local STREAM = {}
    STREAM.__index = STREAM

    STREAM.__tostring = function(s) return string.format("stream[%p][%d][%s]", s, s.id, s.url) end

    STREAM.loaded = false
    STREAM.duration = 0
    STREAM.position = 0
    STREAM.rad3d = 1000
    STREAM.usedoppler = true
    STREAM.url = "" -- ??
    STREAM.paused = true

    function STREAM:__newindex(key, val)
        if key == "OnFFT" then
            if type(val) == "function" then
                self:Call(".usefft(true)")
            else
                self:Call(".usefft(false)")
            end
        end

        rawset(self, key, val)
    end
    
    function STREAM:IsLoaded()
        return self.loaded
    end

    function STREAM:Remove()
        self.IsValid = function() return false end
    end

    function STREAM:IsValid()
        return true
    end
    
    function STREAM:Call(fmt, ...)
        if not self.loaded then return end

        local script = ("try { streams[%d]%s } catch(e) { lua.print(e.toString()) }"):format(self.id, fmt:format(...))
       
        table.insert(webaudio.js_queue, script)
    end

    local function BIND(func_name, js_set, def, check)
        STREAM[func_name] = def

        STREAM["Set" .. func_name] = function(self, var)
            if check then
                var = check(var)
            end

            self[func_name] = var
            self:Call(js_set, var)
        end

        STREAM["Get" .. func_name] = function(self, ...)
            return self[func_name]
        end
    end

    BIND("SamplePosition", ".position = %f", 0)
    BIND("Speed", ".speed = %f", 1)

    STREAM.SetPitch = STREAM.SetSpeed
    STREAM.GetPitch = STREAM.GetSpeed

    webaudio.FILTER =
    {
        NONE = 0,
        LOWPASS = 1,
        HIGHPASS = 2,
    }

    BIND("FilterType", ".filter_type = %i")
    BIND("FilterFraction", ".filter_fraction = %f", 0, function(num) return math.Clamp(num, 0, 1) end)
    
    function STREAM:SetMaxLoopCount(var)
        self:Call(".max_loop = %i", var == true and -1 or var == false and 1 or tonumber(var) or 1)
        self.MaxLoopCount= var
    end
    
    STREAM.SetLooping = STREAM.SetMaxLoopCount

    function STREAM:GetLength()
        return self.Length
    end

    function STREAM:Pause()
        self.paused = true
        self:Call(".play(false)")
    end

    function STREAM:Resume()
        self.paused = false
        self:Call(".play(true)")
    end

    function STREAM:Stop()
        self.paused = true
        self:Call(".play(false, 0)")
    end

    function STREAM:Start()
        self.paused = false
        self:Call(".play(true, 0)")
    end

    STREAM.Play = STREAM.Start

    function STREAM:Restart()
        self:SetSamplePosition(0)
    end

    function STREAM:SetPosition(num)
        self:SetSamplePosition((num%1) * self:GetLength())
    end

    do -- 3d
        function STREAM:Enable3D(b)
            self.use3d = b
        end

        function STREAM:EnableDoppler(b)
            self.usedoppler = b
        end

        function STREAM:Set3DPos(vec)
            self.pos3d = vec
        end

        function STREAM:Get3DPos(vec)
            return self.pos3d
        end

        function STREAM:Set3DRadius(num)
            self.rad3d = num
        end

        function STREAM:Get3DRadius(num)
            return self.rad3d
        end

        function STREAM:Set3DVelocity(vec)
            self.vel3d = vec
        end

        function STREAM:Get3DVelocity(vec)
            return self.vel3d
        end

        local eye_pos, eye_ang, eye_vel, last_eye_pos

        hook.Add("RenderScene", "webaudio_3d", function(pos, ang)
            eye_pos = pos
            eye_ang = ang
            eye_vel = eye_pos - (last_eye_pos or eye_pos)
            
            last_eye_pos = eye_pos
        end)

        function STREAM:Think()
            if self.paused then
            return end

            local ent = self.source_ent

            if ent:IsValid() then
                self.pos3d = ent:GetPos()
            end

            if self.use3d then
                self.pos3d = self.pos3d or Vector()
                self.vel3d = self.vel3d or Vector()
                
                self.vel3d = self.pos3d - (self.last_ent_pos or self.pos3d)                
                self.last_ent_pos = self.pos3d

                local offset = self.pos3d - eye_pos
                local len = offset:Length()
                
                if len < self.rad3d then                    
                    local pan = (offset):GetNormalized():Dot(eye_ang:Right())
                    local vol = math.Clamp((-len + self.rad3d) / self.rad3d, 0, 1) ^ 1.5
                    vol = vol * 0.75 * self.Volume
    
                    self:Call(".vol_right = %f", math.Clamp(1 + pan, 0, 1) * vol)
                    self:Call(".vol_left = %f", math.Clamp(1 - pan, 0, 1) * vol)
    
                    if self.usedoppler then
                        local offset = self.pos3d - eye_pos
                        local relative_velocity = self.vel3d - eye_vel
                        local meters_per_second = offset:GetNormalized():Dot(-relative_velocity) * 0.0254
    
                        self:Call(".speed = %f", self.Speed + (meters_per_second / webaudio.SpeedOfSound))
                    end
                    
                    self.out_of_reach = false
                else
                    if not self.out_of_reach then
                        self:Call(".vol_right = 0")
                        self:Call(".vol_left = 0")     
                        self.out_of_reach = true
                    end
                end
            end
        end

        STREAM.source_ent = NULL

        function STREAM:SetSourceEntity(ent, dont_remove)
            self.source_ent = ent

            if not dont_remove then
                ent:CallOnRemove("webaudio_remove_stream_" .. tostring(self), function()
					if self:IsValid() then
						self:Remove()
					end
                end)
            end
        end
    end

    do -- panning
        STREAM.Panning = 0

        function STREAM:SetPanning(num)
            self.Panning = num

            if not self.use3d then
                self:Call(".vol_right = %f", math.Clamp(1 + num, 0, 1) * self.Volume)
                self:Call(".vol_left = %f", math.Clamp(1 - num, 0, 1) * self.Volume)
            end
        end

        function STREAM:GetPanning()
            return self.Panning
        end
    end

    do -- gain
        STREAM.Volume = 1

        function STREAM:SetVolume(num)
            self.Volume = num
            self:SetPanning(self:GetPanning())
        end

        function STREAM:GetVolume()
            return self.Volume
        end
    end

    local stream_count = 0

    function webaudio.Stream(url)
        url = url:gsub("http[s?]://", "http://")

        if not url:find("http") then
            url = "asset://garrysmod/sound/" .. url
        end

        local stream = setmetatable({}, STREAM)

        stream_count = stream_count + 1

        stream.url = url
        stream.id = stream_count
        webaudio.html:QueueJavascript(string.format("createStream(%q, %d)", url, stream.id))

        webaudio.streams[stream.id] = stream

        return stream
    end
end

local cvar = CreateConVar("pac_ogg_volume", "1")

function webaudio.SetVolume(num)
    webaudio.html:QueueJavascript(string.format("gain.gain.value = %f", num))
end

local last

hook.Add("Think", "webaudio", function()
    local mult = cvar:GetFloat()

    if not webaudio.preinit then
        if webaudio.html then webaudio.html:Remove() end

        local html = vgui.Create("DHTML") or NULL
        if html:IsValid() then

            html:SetVisible(false)
            html:SetPos(ScrW(), ScrH())
            html:SetSize(1, 1)

            html:AddFunction("lua", "print", function(text)
                dprint(text)
            end)

            html:AddFunction("lua", "message", function(name, ...)
                local args = {...}

                if name == "initialized" then
                    webaudio.initialized = true
                    webaudio.rate = args[1]
                elseif name == "stream" then
                    local stream = webaudio.streams[tonumber(args[2]) or 0]

                    if stream then
                        local t = args[1]
                    
                        if t == "call" then    
                            local func_name = args[2]
                            if stream[func_name] then
                                stream[func_name](stream, ...)
                            end
                        elseif t == "fft" then
                            local data = CompileString(args[2], "stream_fft_data")()
                            stream.OnFFT(data)
                        elseif t == "stop" then
                            stream.paused = true
                        elseif t == "return" then
                            stream.returned_var = {select(3, ...)}
                        elseif t == "loaded" then
                            stream.loaded = true
                            stream.Length = args[3]
                            stream:SetFilterType(0)
                            
                            if not stream.paused then
                                stream:Play()
                            end
                            
                            stream:SetMaxLoopCount(stream.MaxLoopCount)

                            if stream.OnLoad then
                                stream:OnLoad()
                            end
                        elseif t == "position" then
                            stream.position = args[3]
                        end
                    end
                end

                dprint(name .. " " .. table.concat({...}, ", "))
            end)

			html:OpenURL("asset://garrysmod/lua/pac3/core/client/libraries/urlogg.lua")
            html:SetHTML(webaudio.html_content)
        end

        webaudio.html = html
        webaudio.preinit = true
    end

    if not webaudio.initialized then return end

    if mult ~= 0 then

        local vol = GetConVarNumber("volume")

        if not system.HasFocus() and GetConVarNumber("snd_mute_losefocus") == 1 then
            vol = 0
        end

        vol = vol * mult

        webaudio.SetVolume(vol)

        for key, stream in pairs(webaudio.streams) do
            if stream:IsValid() then
                stream:Think()
            else
                stream:Stop()
                webaudio.streams[key] = nil
                webaudio.html:QueueJavascript(("destroyStream(%i)"):format(stream.id))

                setmetatable(stream, getmetatable(NULL))
            end
        end
        
        local js = table.concat(webaudio.js_queue, "\n")
        if #js > 0 then
            webaudio.html:QueueJavascript(js)
            webaudio.js_queue = {}
         end
    end
end)

pac.webaudio = webaudio

webaudio.html_content = [==[
<script>

window.onerror = function(description, url, line)
{
    lua.print("Unhandled exception at line " + line + ": " + description)
}

function lerp(x, y, a)
{
    return x * (1 - a) + y * a;
}

var audio, gain, processor, analyser, streams = []

function open()
{
    if(audio)
    {
        audio.destination.disconnect()
        delete audio
        delete gain
    }

    audio = new webkitAudioContext
    processor = audio.createJavaScriptNode(4096, 0, 1);
    gain = audio.createGainNode()
    
    processor.onaudioprocess = function(event)
    {
        var outl = event.outputBuffer.getChannelData(0);
        var outr = event.outputBuffer.getChannelData(1);
        
        for(var i = 0; i < event.outputBuffer.length; ++i)
        {
            outl[i] = 0;
            outr[i] = 0;
        }
        
        for(var i in streams)
        {
            var stream = streams[i]

            if(stream.paused || (stream.vol_left < 0.001 && stream.vol_right < 0.001))
            {
                continue;
            }
		
            var inl = stream.buffer.getChannelData(0)
            var inr = stream.buffer.numberOfChannels == 1 ? inl : stream.buffer.getChannelData(1)
	
			var sml = 0
			var smr = 0
	
            for(var j = 0; j < event.outputBuffer.length; ++j)
            {
                var length = stream.buffer.length;
                
                if (stream.max_loop > 0 && stream.position > length * stream.max_loop)
                    break
                
                var speed = stream.use_smoothing ? stream.speed_smooth : stream.speed
                
                var index = (stream.position >>> 0) % length;

                if (stream.filter_type != 0)
                {                                 
                    sml = sml + (inl[index] - sml) * stream.filter_fraction
                    smr = smr + (inr[index] - smr) * stream.filter_fraction
                
                    if (stream.filter_type == 2)
                    {
                        outl[j] += (inl[index] - sml) * stream.vol_left
                        outr[j] += (inr[index] - smr) * stream.vol_right
                    }
                    else
                    {
                        outl[j] += sml * stream.vol_left
                        outr[j] += smr * stream.vol_right                    
                    }                    
                
                }
                else
                {
                    outl[j] += inl[index] * stream.vol_left
                    outr[j] += inr[index] * stream.vol_right
                }                
              
                stream.position += speed
                
                if (stream.use_smoothing)
                    stream.speed_smooth = stream.speed_smooth + (stream.speed - stream.speed_smooth) * 0.0005
            }
        }
    };

    processor.connect(gain)
    gain.connect(audio.destination)

    lua.message("initialized", audio.sampleRate)
}

function close()
{
    if(audio)
    {
        audio.destination.disconnect();
        delete audio
        audio = null
        lua.message("uninitialized")
    }
}

var buffer_cache = []

function download_buffer(url, callback, skip_cache)
{
    if (!skip_cache && buffer_cache[url])
    {
        callback(buffer_cache[url])
        
        return
    }

    var request = new XMLHttpRequest

    request.open("GET", url)
    request.responseType = "arraybuffer"
    request.send()

    request.onload = function()
    {
        lua.print("loaded \"" + url + "\"")
        lua.print("status " + request.status)

        lua.print("decoding " + request.response.byteLength + " ...")

        audio.decodeAudioData(request.response, 
            
            function(buffer)
            {
                lua.print("decoded successfully")
    
                callback(buffer)   
                
                buffer_cache[url] = buffer   
            },
            
            function(err)
            {
                lua.print("decoding error " + err)
            }
        )
    }

    request.onprogress = function(event)
    {
        lua.print("downloading " +  (event.loaded / event.total) * 100)
    }

    request.onerror = function()
    {
        lua.print("downloading " + url + " errored")
    };
}

function createStream(url, id, skip_cache)
{
    lua.print("Loading " + url)

    download_buffer(url, function(buffer)
    {
        var stream = {}

        stream.id = id
        stream.position = 0
        stream.buffer = buffer
        stream.url = url
        stream.speed = 1 // 1 = normal pitch
        stream.speed_smooth = stream.speed
        stream.max_loop = 1 // -1 = inf
        stream.vol_left = 1
        stream.vol_right = 1
        stream.filter = audio.createBiquadFilter();
        stream.paused = true
        stream.use_smoothing = true
        stream.echo_volume = 0
        stream.filter_type = 0
        stream.filter_fraction = 1

        stream.play = function(stop, position)
        {
            if(position !== undefined)
            {
                stream.position = position
            }

            stream.paused = !stop
        };
        
        stream.usefft = function(enable)
        {
            // later
        }

        streams[id] = stream

        lua.message("stream", "loaded", id, buffer.length)
    }, skip_cache)
}

function destroyStream(id)
{
}

open()

</script>

]==]