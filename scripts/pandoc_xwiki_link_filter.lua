function Link(el)
    local target = el.target

    -- Skip external links
    if target:match("^https?://") then
        return el
    end

    -- Remove leading slash
    target = target:gsub("^/", "")

    -- Convert slashes to dots (XWiki space notation)
    target = target:gsub("/", ".")

    -- Ensure .WebHome at the end
    if not target:match("%.WebHome$") then
        target = target .. ".WebHome"
    end

    -- Reconstruct the link
    return pandoc.Link(el.content, target)
end

