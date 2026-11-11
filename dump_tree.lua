local Config = {
    root = game,
    maxDepth = 10,
    maxChildren = 40,
    maxNodes = 5000,
    outputFile = "client_tree.txt",
}

---------------------------------------------------------------------------
-- Tree
---------------------------------------------------------------------------

local Tree = {}

local function childrenOf(instance)
    local ok, children = pcall(function()
        return instance:GetChildren()
    end)
    if ok then
        return children
    end
    return {}
end

local function label(instance)
    return ("%s [%s]"):format(instance.Name, instance.ClassName)
end

function Tree.build(root, config)
    local lines = {}
    local count = 0
    local truncated = false

    local function add(text)
        count += 1
        lines[#lines + 1] = text
    end

    local function walk(instance, prefix, depth)
        local children = childrenOf(instance)
        local total = #children
        local limit = math.min(total, config.maxChildren)

        for index = 1, limit do
            if count >= config.maxNodes then
                if not truncated then
                    truncated = true
                    add(prefix .. "… truncated")
                end
                return
            end

            local child = children[index]
            local last = index == limit and total <= config.maxChildren
            local branch = last and "└─ " or "├─ "
            local childPrefix = prefix .. (last and "   " or "│  ")

            add(prefix .. branch .. label(child))

            if depth < config.maxDepth then
                walk(child, childPrefix, depth + 1)
            elseif #childrenOf(child) > 0 then
                add(childPrefix .. "…")
            end
        end

        if total > config.maxChildren then
            add(prefix .. ("… +%d more"):format(total - config.maxChildren))
        end
    end

    add(label(root))
    walk(root, "", 1)

    return table.concat(lines, "\n"), count
end

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------

local Output = {}

function Output.save(text)
    if type(writefile) ~= "function" then
        return nil
    end
    local ok = pcall(writefile, Config.outputFile, text)
    if ok then
        return Config.outputFile
    end
    return nil
end

function Output.clipboard(text)
    if type(setclipboard) ~= "function" then
        return false
    end
    return pcall(setclipboard, text)
end

---------------------------------------------------------------------------
-- Main
---------------------------------------------------------------------------

local text, count = Tree.build(Config.root, Config)
local path = Output.save(text)
Output.clipboard(text)

if path then
    print(("[tree] %d lines saved to %s"):format(count, path))
end

print(text)
