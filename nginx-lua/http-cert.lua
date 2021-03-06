--Don't use .lua to load
local CoreVariables = require("/var/www/html/website/nginx-lua/http-https-core-veriables")
local CoreFunctions = require("/var/www/html/website/nginx-lua/http-https-core-functions")

local coreVariables = CoreVariables:new()
local coreFunctions = CoreFunctions:new(coreVariables)

local function RedirectToHTTPS()
    return ngx.redirect("https://" .. ngx.var.host .. ngx.var.request_uri)
end

local function CheckSNIName()
    coreVariables.server_name = ngx.var.host

    --Remove me
    -----------------------------------------------------------------------------------------------------
    coreVariables.server_name = string.gsub(ngx.var.request_uri, "/ssltest/", "")
    -----------------------------------------------------------------------------------------------------
end

local function HandleYourHTTPSite()
    --    local clock = os.clock
    --    local start = clock()

    CheckSNIName()

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

        local hasRedisConnectionErr = coreFunctions.Init() -- default false; means no connection error

        --        local endtiem = (clock() - start)
        --        coreFunctions.Print("----------------------")
        --        coreFunctions.Print("Total Time In Seconds: " .. endtiem)
        --        coreFunctions.Print("Total Time In Readable Seconds: " .. endtiem * 1000)

        if hasRedisConnectionErr == false then
            if coreVariables.currentCertStatus == coreVariables.valid then
                --RedirectToHTTPS()
            else
                coreFunctions.Print("Not Valid; Status: " .. coreVariables.currentCertStatus)
            end
        else
            coreFunctions.Print("Not Valid (Redis or Convertion ERROR); Status: " .. coreVariables.currentCertStatus)
        end
    end
end

HandleYourHTTPSite()

--coreFunctions.Print(collectgarbage("count") .. ' kilobytes memory used')