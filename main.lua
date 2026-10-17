local cjson = require("cjson")

local function library(title, fields)
	return
	{
		form = {
			title = title,
			fields = fields
		}
	}
end

local function textbox(name, label, required, initial)
	return
	{
		type = "text",
		name = name,
		label = label,
		required = required,
		initial = initial
	}
end

local function number(name, label, required, initial)
	return
	{
		type = "numeric",
		name = name,
		label = label,
		required = required,
		initial = initial
	}
end

local function dropdown(name, label, required, initial)
	return
	{
		type = "choice",
		name = name,
		label = label,
		required = required,
		options = initial
	}
end

local function checkbox(name, label, initial)
	return
	{
		type = "checkbox",
		name = name,
		label = label,
		initial = initial
	}
end

local function divider()
	return
	{
		type = "divider"
	}
end

local function build(menu)
	local main = app.jsonForm(cjson.encode(menu))
	if (not main or (main == "")) then
		return nil
	end
	local result = cjson.decode(main)
	for _, field in ipairs(menu.form.fields) do
		if field.type == "numeric" then
			local value = tonumber(result[field.name]) or 0
			if value % 1 == 0 then
				result[field.name] = math.tointeger and math.tointeger(value) or value
			else
				result[field.name] = value
			end
		end
	end
	return result
end

LuaWebCrawler = build(library("LuaWebCrawler", {
	textbox("url", "Enter specific URL", true, "https://example.com"),
	number("maxpage", "Max Pages", false, "20"),
	divider()
}))

if not LuaWebCrawler then
	app.toast("User has cancelled the session.")
	return
end


local start_url = LuaWebCrawler.url
local max_pages = LuaWebCrawler.maxpage

local visited = {}
local queue = {start_url}
local count = 1

local function get_domain(url)
	return url:match("^https?://([^/]+)")
end

local base_domain = get_domain(start_url)

while count <= #queue and count <= max_pages do
	local url = queue[count]
	count = count + 1

	if not visited[url] then
		visited[url] = true

		print("Scanning: " .. url)

		local status, html = app.httprequest({
			url = url,
			method = "GET"
		})

		if status == 200 and html then
			local found = 0

			for link in html:gmatch('href%s*=%s*["\']([^"\']+)["\']') do
				local next_url = nil

				if link:match("^https?://") then
					if get_domain(link) == base_domain then
						next_url = link
					end
				elseif link:sub(1, 1) == "/" and
					   link:sub(1, 2) ~= "//" then
					next_url = "https://" .. base_domain .. link
				end

				if next_url and not visited[next_url] then
					local exists = false

					for _, queued in ipairs(queue) do
						if queued == next_url then
							exists = true
							break
						end
					end

					if not exists then
						queue[#queue + 1] = next_url
						found = found + 1
					end
				end
			end

			print("Links discovered: " .. found)
		else
			print("Request failed: " .. tostring(status))
		end
	end
end

print("Crawl completed.")
print("Pages visited: " .. tostring(count - 1))
