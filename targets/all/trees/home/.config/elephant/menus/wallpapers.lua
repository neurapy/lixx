Name = "lixx-wallpapers"
NamePretty = "Wallpapers"
Cache = false
SearchName = true

function GetEntries()
    local entries = {}
    local images = io.popen("lixx-wallpaper list")
    if not images then return entries end
    for path in images:lines() do
        local filename = path:match("([^/]+)$")
        local quoted = "'" .. path:gsub("'", "'\\''") .. "'"
        table.insert(entries, {
            Text = filename,
            Value = path,
            Preview = path,
            PreviewType = "file",
            Actions = { activate = "lixx-wallpaper set " .. quoted },
        })
    end
    images:close()
    return entries
end
