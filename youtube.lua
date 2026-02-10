-- Improved error handling for YouTube URL processing  
local function getYoutubeVideoID(url)  
    local videoID  
    local patterns = {  
        "youtube%.com/watch%?v=([%w-]*)",  
        "youtu%.be/([%w-]*)",  
        "youtube%.com/embed/([%w-]*)"  
    }  
    for _, pattern in ipairs(patterns) do  
        local match = url:match(pattern)  
        if match then  
            videoID = match  
            break  
        end  
    end  
    return videoID  
end  
  
-- Function to handle YouTube video URLs  
function handleYoutubeURL(url)  
    local videoID = getYoutubeVideoID(url)  
    if not videoID then  
        error("Invalid YouTube URL.")  
    end  
    local command = string.format("youtube-dl -f best https://www.youtube.com/watch?v=%s", videoID)  
    os.execute(command)  
end  
  
-- Main function to test URL handling  
function main()  
    local testURLs = {  
        "https://www.youtube.com/watch?v=someVideoID",  
        "https://youtu.be/anotherVideoID",  
        "https://www.youtube.com/embed/videoID123",  
        "invalid_url"  
    }  
    for _, url in ipairs(testURLs) do  
        pcall(function()  
            handleYoutubeURL(url)  
        end)  
    end  
end  
  
main()
