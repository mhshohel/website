local CoreVariables = require("/var/www/html/website/nginx-lua/http-https-core-veriables")
local CoreFunctions = require("/var/www/html/website/nginx-lua/http-https-core-functions")

local coreVariables = CoreVariables:new()
local coreFunctions = CoreFunctions:new(coreVariables)

local function RequestCachedCertificate()
    -- only request for cached certificate; don't order
--    ngx.say("Request new certificate or status from cert server")
end

local function HTTPRedirect80()
--    ngx.say("Redirect to HTTP")
end

local function ClearSSLCertificate()
    local ok, err           = ssl.clear_certs()
    if not ok then
        ngx.log(ngx.OK, "Failed to clear existing (fallback) certificates")
        return false
    end
    return true
end

local function LoadSSLCertificate()
    local res = ClearSSLCertificate()

    if res == true then
--        ngx.say("Cleared")
    else
--        ngx.say("NOT Cleared")
    end
end

local function HTTPSRedirect443()
--    ngx.say(ngx.var.server_port)
--    ngx.say("Redirect to HTTPS or HTTP depending on PORT")
end

local function HandleYourHTTPSite()
    local hasRedisConnectionErr = false -- default false

    coreFunctions.SetupRedisKeyName()

    if coreFunctions.GetFromLua() == false then
        hasRedisConnectionErr = coreFunctions.GetCertFromRedis()
    end

    if hasRedisConnectionErr == false then
        if coreVariables.currentCertStatus == coreVariables.valid then
            coreFunctions.Print("Valid; Status: " .. coreVariables.currentCertStatus)
        else
            coreFunctions.Print("Not Valid; Status: " .. coreVariables.currentCertStatus)
        end
    else
        coreFunctions.Print("Not Valid (Redis or Convertion ERROR); Status: " .. currentCertStatus)
    end

    coreFunctions.Print("......................")
    coreFunctions.Print(coreVariables.expireDuration / 86400 .. " days")
    coreFunctions.Print(coreVariables.expireDuration .. " seconds")
    coreFunctions.Print("......................")
end

local function CheckSNIName()
    coreVariables.server_name = ngx.var.host

    --Remove me
    -----------------------------------------------------------------------------------------------------
    coreVariables.server_name = string.gsub(ngx.var.request_uri, "/ssltest/", "")
    -----------------------------------------------------------------------------------------------------
end

local function Main()
    CheckSNIName()

    coreFunctions.Print(coreVariables.server_name)

    if not string.find(ngx.var.request_uri, "/.well%-known/acme%-challenge/") and
        not string.find(coreVariables.server_name, ".portfoliobox.net") and
        not string.find(coreVariables.server_name, ".pb.design") and
        not string.find(coreVariables.server_name, ".pb.gallery") and
        not string.find(coreVariables.server_name, ".pb.online") and
        not string.find(coreVariables.server_name, ".pb.photography") and
        not string.find(coreVariables.server_name, ".pb.studio") and
        not string.find(coreVariables.server_name, ".pb.store") and
        not string.find(coreVariables.server_name, ".pb.style") and
        not string.find(coreVariables.server_name, ".cloudfront.net") then

        local clock = os.clock
        local start = clock()

        coreFunctions.Print("Handle SSL");

        HandleYourHTTPSite()

        local endtiem = (clock() - start)
        coreFunctions.Print("----------------------")
        coreFunctions.Print("Total Time In Seconds: " .. endtiem)
        coreFunctions.Print("Total Time In Readable Seconds: " .. endtiem * 1000)
        coreFunctions.Print("----------------------")
    end
end

Main()


coreFunctions.Print(collectgarbage("count") .. ' kilobytes memory used')
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