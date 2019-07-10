-------------------------------------------------------------------------------
-- includes a new tostring function that handles tables recursively
--
-- @author Danilo Tuler (tuler@ideais.com.br)
-- @author Andre Carregal (info@keplerproject.org)
-- @author Thiago Costa Ponte (thiago@ideais.com.br)
--
-- @copyright 2004-2019 Kepler Project, Milind Gupta
-------------------------------------------------------------------------------

local type, table, string, _tostring, tonumber = type, table, string, tostring, tonumber
local select = select
local error = error
local format = string.format
local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable

-- Create the module table here
local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

_VERSION = "2019.07.09.01"
-- Meta information
_COPYRIGHT = "Copyright (C) 2004-2019 Kepler Project, Milind Gupta"
_DESCRIPTION = "A simple API to use logging features in Lua"

local DEFAULT_LEVELS = {
	-- The highest possible rank and is intended to turn off logging.
	"OFF",
	-- The FATAL level designates very severe error events that will presumably
	-- lead the application to abort
	"FATAL",
	-- The ERROR level designates error events that might still allow the
	-- application to continue running
	"ERROR",
	-- The WARN level designates potentially harmful situations
	"WARN",
	-- The INFO level designates instring.formational messages that highlight the
	-- progress of the application at coarse-grained level
	"INFO",
	-- The DEBUG Level designates fine-grained instring.formational events that are most
	-- useful to debug an application
	"DEBUG",
	-- Most detailed information. Expect these to be written to logs only
	"TRACE"
}

-- private log function, with support for formating a complex log message.
local function LOG_MSG(self, level, fmt, ...)
	if type(fmt) == 'string' then
		if select('#', ...) > 0 then
			local status, msg = pcall(format, fmt, ...)
			if status then
				return self:append(level, msg)
			else
				return self:append(level, "Error formatting log message: " .. msg)
			end
		else
			-- only a single string, no formating needed.
			return self:append(level, fmt)
		end
	elseif type(fmt) == 'function' then
		-- fmt should be a callable function which returns the message to log
		return self:append(level, fmt(...))
	end
	-- fmt is not a string and not a function, just call append with all arguments
	return self:append(level,fmt, ...)
end

-------------------------------------------------------------------------------
-- Prepares the log message
-------------------------------------------------------------------------------
function prepareLogMsg(pattern, dt, level, message)
	local logMsg = pattern or "%date %level %message\n"
	message = string.gsub(message, "%%", "%%%%")
	logMsg = string.gsub(logMsg, "%%date", dt)
	logMsg = string.gsub(logMsg, "%%level", level)
	logMsg = string.gsub(logMsg, "%%message", message)
	return logMsg
end


-------------------------------------------------------------------------------
-- Creates a new logger object
-- @param append Function used by the logger to append a message with a
--	log-level to the log stream.
-- @return Table representing the new logger object.
-------------------------------------------------------------------------------
function new(append,settings)
	if type(append) ~= "function" then
		return nil, "Appender must be a function."
	end

	local logger = {}
	logger.append = append

	-- initialize all default values
	if type(settings) ~= "table" then
		settings = {}
	end
	setmetatable(settings, {
		__index = {
			levels = DEFAULT_LEVELS,
			init_level = DEFAULT_LEVELS[6]	-- Default level is DEBUG
		}
	})
	
	-- settings contains the logging levels and everything is referenced from this
	
	logger.setLevel = function (self, level)
		local order
		if type(level) == "number" then
			order = level
			level = settings.levels[order]
		elseif type(level) == "string" then
			for i = 1,#settings.levels do
				if settings.levels[i] == level then
					order = i
					break
				end
			end
		end
		if not level then
			return
		end
		if not order then
			return
		end
		settings.level = level	-- String name of the level
		settings.level_order = order	-- order number of the level
		return true
	end

	-- generic log function.
	logger.log = function (self, level, ...)
		local order
		if type(level) == "number" then
			order = level
			level = settings.levels[order]
		elseif type(level) == "string" then
			for i = 1,#settings.levels do
				if settings.levels[i] == level then
					order = i
					break
				end
			end
		end
		if order and order <= settings.level_order then
			return LOG_MSG(self, level, ...)
		else
			return
		end
	end

	-- Per level function.
	for _,l in pairs(settings.levels) do
		if type(l) == 'string' then
			logger[l:lower()] = function(self, ...)
				return self:log(l, ...)
			end
		end
	end

	-- initialize log level.
	logger:setLevel(settings.init_level)

	setmetatable(logger,{
			__index = function(t,k)
				if k == "levels" then
					return settings.levels
				elseif k == "init_level" then
					return settings.init_level
				elseif k == "level" then
					return settings.level
				end			
			end,
			__newindex = function(t,k,v)
				if k == "levels" and type(v) == "table" then
					-- Check if any string levels
					local found
					for i = 1,#v do
						if type(v[i]) == "string" then
							found = true
							break
						end
					end
					if found then
						-- Per level function.
						for _,l in pairs(settings.levels) do
							if type(l) == 'string' then
								t[l:lower()] = nil
							end
						end
						settings.levels = v
						-- Per level function.
						for _,l in pairs(settings.levels) do
							if type(l) == 'string' then
								t[l:lower()] = function(self, ...)
									return self:log(l, ...)
								end
							end
						end
						if #v > 1 then
							t:setLevel(#v-1)	-- Set the default level as 1 less than total
						else
							t:setLevel(#v)
						end
					end
				elseif k == "level" then
					t:setLevel(v)
				end
			end
		}	
	)
	return logger
end




