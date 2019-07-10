require("submodsearcher")
local log_sql = require "logging.sql"
local has_module, err = pcall(require, "luasql.sqlite3")
if not has_module then
	print("SQLite 3 Logging SKIP (missing luasql.sqlite3)")
else
	luasql = require("luasql.sqlite3")
	if not luasql or not luasql.sqlite3 then
		print("Missing LuaSQL SQLite 3 driver!")
	else
		local env, err = luasql.sqlite3()

		local logger = log_sql{
			connectionfactory = function()
				local con, err = env:connect("test.db")
				assert(con, err)
				-- Check if LogTable exists
				local cur
				cur,err = con:execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")
				assert(cur,err)
				local name = cur:fetch()
				local found
				while name do
					if name == "LogTable" then
						found = true
						break
					end
					name = cur:fetch()
				end
				if not found then
					con:execute([[CREATE TABLE "LogTable" ("LogDate"	TEXT,"LogLevel"	TEXT,"LogMessage"	TEXT);]])
				end
				return con
			end,
			keepalive = true,
			tablename = "LogTable",
			logdatefield = "LogDate",
			loglevelfield = "LogLevel",
			logmessagefield = "LogMessage"
		}

		logger:info("logging.sql test")
		logger:debug("debugging...")
		logger:error("error!")
		-- Check the logging data here
		local con,cur
		con,err = env:connect("test.db")
		assert(con,err)
		cur,err = con:execute([[SELECT * FROM LogTable;]])
		assert(cur,err)
		local t = {cur:fetch()}
		local index = 1
		local check = {
				{"INFO","logging.sql test"},
				{"DEBUG","debugging..."},
				{"ERROR","error!"}
		}
		while #t==3 do
			--[[print("T#=",#t)
			print("Index=",index)
			print(t[1])
			print(t[2])
			print(t[3])
			print(check[index][1])
			print(check[index][2])]]
			assert(t[2] == check[index][1],"Index "..index.." mismatch on level")
			assert(t[3] == check[index][2],"Index "..index.." mismatch on message")
			t = {cur:fetch()}
			index = index + 1
		end
		print("SQLite 3 Logging OK")
	end
end

