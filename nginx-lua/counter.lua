local function monitor()
    local ServerName = ngx.var.server_name;
    local Status = ngx.var.status;
    local List = ngx.shared.requests_counter;
    local NotAllowled = { ['200'] = false, ['404'] = false}; --Other than 200 and 404
    local Status_200 = { ['200'] = true };
    local Status_404 = { ['404'] = true };

    local keys = {
        ["Total"] = ServerName .. "-> Total",
        ["Proxy"] = ServerName .. "-> Proxy",
        ["NotAllowed"] = ServerName .. "-> NotAllowled",
        ["Status_200"] = ServerName .. "-> Status_200",
        ["Status_404"] = ServerName .. "-> Status_404"
    };

    for _, _key in pairs(keys) do
        local temp_val = List:get(keys[_key]);

        if temp_val == nil then
            List:add(_key, 0);
        end

        --anyone know what will be when "temp_val" reach self limit? Its will be equal to zero?
        if temp_val and temp_val >= 70368744177664 then --math.pow(2, 46) value
            List:set(_key, 0);
        end
    end

    List:incr(keys.Total, 1);

    if ngx.var.upstream_status ~= nil then
        List:incr(keys.Proxy, 1);
    end

    if NotAllowled[Status] then
        List:incr(keys.NotAllowed, 1);
    end

    if Status_200[Status] then
        List:incr(keys.Status_200, 1);
    end

    if Status_404[Status] then
        List:incr(keys.Status_404, 1);
    end

    local MaxRequestTime = List:get("MaxRequestTime");

    if MaxRequestTime == nil then
        List:set("MaxRequestTime", ngx.var.request_time);
    else
        if MaxRequestTime < ngx.var.request_time then
            List:set("MaxRequestTime", ngx.var.request_time);
        end
    end
end

monitor();