local Library = require "CoronaLibrary"

-- Create stub library for simulator
local lib = Library:new{ name='plugin.vungle', publisherId='com.vungle' }

-- Default implementations
local function defaultFunction()
    print( "WARNING: The '" .. lib.name .. "' library is not available on this platform." )
end

lib.init= defaultFunction
lib.requestToken= defaultFunction
lib.allowsApplePay= defaultFunction

-- Return an instance
return lib