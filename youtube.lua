-- YouTube Link Resolver for VLC with Improved Error Handling and Better Reliability
-- Place this script in VLC's lua/playlist directory

local yt_dlp_path = 'yt-dlp.exe'
local yt_dlp_silent_path = 'ytdlp-silent-xp.exe'

function sleep(ms)
    local start = os.clock()
    while os.clock() - start < (ms / 1000) do end
end

function probe()
    -- Check if the input is a YouTube link
    if not (vlc.access == "http" or vlc.access == "https") then
        return false
    end
    
    local patterns = {
        "youtube%.com",
        "youtu%.be",
        "youtube%-nocookie%.com",
        "m%.youtube%.com"
    }
    
    for _, pattern in ipairs(patterns) do
        if string.match(vlc.path, pattern) then
            return true
        end
    end
    return false
end

function parse()
    -- Construct the full YouTube URL
    local youtube_url = vlc.access .. "://" .. vlc.path
    
    if not youtube_url or youtube_url == "" then
        vlc.msg.err("[YouTube Resolver] Failed to construct URL")
        return {}
    end

    -- Extract "quality" query parameter if present
    local quality = youtube_url:match("[&?]quality=(%d+)[pP]?")
    youtube_url = youtube_url:gsub("[&?]quality=%d+[pP]?"):gsub("[&?]$", "")

    local allowed_qualities = {
        ["360"] = true,
        ["480"] = true,
        ["720"] = true,
        ["1080"] = true,
        ["2160"] = true
    }

    local format_string = "bestvideo+bestaudio"
    if quality and allowed_qualities[quality] then
        format_string = string.format("bestvideo[height=%s]+bestaudio", quality)
        vlc.msg.info("Using requested quality: " .. quality .. "p")
    else
        vlc.msg.info("Defaulting to best available quality")
    end

    local video_url = ''
    local audio_url = ''
    
    local yt_dlp_silent_exists = io.open(yt_dlp_silent_path, "r") ~= nil
    
    if not yt_dlp_silent_exists then
        vlc.msg.info("Using fallback yt-dlp method")
        
        local cmd = string.format(
            'PowerShell.exe -windowstyle hidden cmd /c & "%s" -f "%s" -g --no-warnings "%s",
            yt_dlp_path,
            format_string,
            youtube_url
        )

        local handle = io.popen(cmd)
        if handle then
            video_url = handle:read("*l") or ""
            audio_url = handle:read("*l") or ""
            handle:close()
        else
            vlc.msg.err("[YouTube Resolver] Failed to execute yt-dlp")
            return {}
        end
    else
        vlc.msg.info(yt_dlp_silent_path .. " found. Running program")
        local cmd = string.format(
            '%s -s "%s -f "%s" -g --no-warnings %s",
            yt_dlp_silent_path,
            yt_dlp_path,
            format_string,
            youtube_url
        )

        local process = io.popen("start /B " .. cmd)
        process:close()

        local output_file = "yt-dlp-output.txt"
        local file_exists = false
        local timeout = 0
        local timeout_limit = 10

        while not file_exists do
            local file_test = os.rename(output_file, output_file)
            if file_test then
                file_exists = true
            else
                vlc.msg.info("Waiting for output file...")
                sleep(1000)
                timeout = timeout + 1
                if timeout > timeout_limit then
                    vlc.msg.warn("Timeout reached. The output file was not created.")
                    break
                end
            end
        end

        if file_exists then
            vlc.msg.info("File found")
            local file = io.open(output_file, "r")
            if file then
                video_url = file:read("*l") or ""
                audio_url = file:read("*l") or ""
                file:close()
                os.remove(output_file)
            end
        end
    end

    -- Trim whitespace
    video_url = video_url:gsub("^%%s+", ""):gsub("%s+$", "")
    audio_url = audio_url:gsub("^%%s+", ""):gsub("%s+$", "")

    if not video_url or video_url == "" then
        vlc.msg.err("[YouTube Resolver] Failed to extract video URL from: " .. youtube_url)
        return {}
    end

    vlc.msg.info("[YouTube Resolver] Original URL: " .. youtube_url)
    vlc.msg.info("[YouTube Resolver] Video URL: " .. video_url)

    if audio_url and audio_url ~= "" then
        return {
            {
                path = video_url,
                name = vlc.path .. " (Video)",
                options = {
                    ":input-slave=" .. audio_url
                }
            }
        }
    else
        return {
            {
                path = video_url,
                name = vlc.path .. " (Video + Audio)"
            }
        }
    end
end
