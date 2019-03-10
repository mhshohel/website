--Don't use .lua to load
local CoreVariables = require("/var/www/html/website/nginx-lua/http-https-core-veriables")
local CoreFunctions = require("/var/www/html/website/nginx-lua/http-https-core-functions")

local coreVariables = CoreVariables:new()
local coreFunctions = CoreFunctions:new(coreVariables)

local function CheckSNIName()
    local sni, err      = coreVariables.ssl.server_name()
    if not err then
        coreVariables.server_name = sni
    else
        ngx.exit(ngx.ERR, "Server name (SNI) not found...")   -- Exit only on ERROR
    end

    -- Remove ME
    -----------------------------------------------------------------------------------------------------
    coreVariables.server_name = "www.publicdomain310.com"
    -----------------------------------------------------------------------------------------------------
end

local function ClearSSLCertificate()
    local ok, err           = coreVariables.ssl.clear_certs()
    if not ok then
        coreFunctions.SetStatusRequested()
        coreFunctions.Print("Clear Certificate")
    end
end

local function LoadCertificateToSSL()
    --fullchain.crt
    local ok, err           = coreVariables.ssl.set_der_cert(coreVariables.currentFullChain)
    if not ok then
        coreFunctions.SetStatusRequested()
        coreFunctions.Print("Failed to set certificate (fullchain.crt) DER")
    end
end

local function LoadPrivateKeyToSSL()
    --private.pem
    local ok, err           = coreVariables.ssl.set_der_priv_key(coreVariables.currentDomainKey)
    if not ok then
        coreFunctions.SetStatusRequested()
        coreFunctions.Print("Failed to set key (private.pem) DER")
    end
end

local function LoadCertificate()
    coreFunctions.Print("Load SSL Certificate...")

    ClearSSLCertificate()
    LoadCertificateToSSL()
    LoadPrivateKeyToSSL()
end

local function HandleYourHTTPSSite()
    local clock = os.clock
    local start = clock()

    CheckSNIName()

    coreFunctions.Print(coreVariables.server_name)

    local hasRedisConnectionErr = coreFunctions.Init() -- default false; means no connection error

    local endtiem = (clock() - start)
    coreFunctions.Print("----------------------")
    coreFunctions.Print("Total Time In Seconds: " .. endtiem)
    coreFunctions.Print("Total Time In Readable Seconds: " .. endtiem * 1000)
    coreFunctions.Print("----------------------")

    coreFunctions.Print("......................")
    coreFunctions.Print(coreVariables.expireDuration / 86400 .. " days")
    coreFunctions.Print(coreVariables.expireDuration .. " seconds")
    coreFunctions.Print("......................")

    if hasRedisConnectionErr == false then
        if coreVariables.currentCertStatus == coreVariables.valid then
            coreFunctions.Print("Valid; Status: " .. coreVariables.currentCertStatus)

            --LOAD SSL
            LoadCertificate()
        else
            coreFunctions.Print("Not Valid; Status: " .. coreVariables.currentCertStatus)
            coreFunctions.Print("REDIRECT TO HTTP (90)")
        end
    else
        coreFunctions.Print("Not Valid (Redis or Convertion ERROR); Status: " .. currentCertStatus)
        coreFunctions.Print("REDIRECT TO HTTP (90)")
    end
end

HandleYourHTTPSSite()

coreFunctions.Print(collectgarbage("count") .. ' kilobytes memory used')