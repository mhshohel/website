local CoreVariables = require("/var/www/html/website/nginx-lua/http-https-core-veriables")
local CoreFunctions = require("/var/www/html/website/nginx-lua/http-https-core-functions")

local coreVariables = CoreVariables:new()
local coreFunctions = CoreFunctions:new(coreVariables, true)

local function HandleYourHTTPSSite()
    local hasRedisConnectionErr = false -- default false

    coreFunctions.SetupRedisKeyName()

    if coreFunctions.GetFromLua() == false then
        hasRedisConnectionErr = coreFunctions.GetCertFromRedis()
    end

    if hasRedisConnectionErr == false then
        if coreVariables.currentCertStatus == coreVariables.valid then
            coreFunctions.Print("Valid; Status: " .. coreVariables.currentCertStatus, true)
        else
            coreFunctions.Print("Not Valid; Status: " .. coreVariables.currentCertStatus, true)
        end
    else
        coreFunctions.Print("Not Valid (Redis or Convertion ERROR); Status: " .. currentCertStatus, true)
    end

    coreFunctions.Print("......................", true)
    coreFunctions.Print(coreVariables.expireDuration / 86400 .. " days", true)
    coreFunctions.Print(coreVariables.expireDuration .. " seconds", true)
    coreFunctions.Print("......................", true)
end

local function CheckSNIName()
    local sni, err      = coreVariables.ssl.server_name()
    if not err then
        coreVariables.server_name = sni
    else
        ngx.exit(ngx.ERR, "Server name (SNI) not found...")   -- Exit only on ERROR
    end

    -- Remove ME
    -----------------------------------------------------------------------------------------------------
    coreVariables.server_name = "www.publicdomain3187.com"
    -----------------------------------------------------------------------------------------------------
end

local function Main()
    CheckSNIName()

    coreFunctions.Print(coreVariables.server_name, true)

    local clock = os.clock
    local start = clock()

    coreFunctions.Print("Handle SSL", true);

    HandleYourHTTPSSite()

    local endtiem = (clock() - start)
    coreFunctions.Print("----------------------", true)
    coreFunctions.Print("Total Time In Seconds: " .. endtiem, true)
    coreFunctions.Print("Total Time In Readable Seconds: " .. endtiem * 1000, true)
    coreFunctions.Print("----------------------", true)
end

Main()

coreFunctions.Print(collectgarbage("count") .. ' kilobytes memory used', true)

--ngx.say(collectgarbage("count") .. ' kilobytes memory used')
--coreVaariables = ngx.null
--ngx.say(collectgarbage("count"))


--return ngx.redirect("http://www.google.com")
--echo "$server_port:$request_uri"

--ngx.STDERR
--ngx.EMERG
--ngx.ALERT
--ngx.CRIT
--ngx.ERR
--ngx.WARN
--ngx.NOTICE
--ngx.INFO
--ngx.DEBUG