local func = require "track_design_patterns/func"
local coor = require "track_design_patterns/coor"
local arc = require "track_design_patterns/coorarc"
local line = require "track_design_patterns/coorline"
local quat = require "track_design_patterns/quaternion"
local station = require "track_design_patterns/stationlib"
local pipe = require "track_design_patterns/pipe"
local tdp = require "track_design_patterns"
local livetext = require "livetext"

local tdpp = {}

local unpack = table.unpack
local ma = math
local abs = ma.abs
local ceil = ma.ceil
local floor = ma.floor
local pi = ma.pi
local atan = ma.atan
local pow = ma.pow
local cos = ma.cos
local sin = ma.sin
local asin = ma.asin
local min = ma.min
local atan2 = ma.atan2
local sqrt = ma.sqrt


local cov = function(m)
    return func.seqMap({0, 3}, function(r)
        return func.seqMap({1, 4}, function(c)
            return m[r * 4 + c]
        end)
    end)
end

tdpp.findMarkers = function(group)
    return pipe.new
        * game.interface.getEntities({pos = game.gui.getTerrainPos(), radius = 9999})
        * pipe.map(game.interface.getEntity)
        * pipe.filter(function(data) return data.fileName and string.match(data.fileName, "tdp_planner.con") and data.params and data.params.group == group end)
        * pipe.sort(function(x, y) return x.dateBuilt.year < y.dateBuilt.year or x.dateBuilt.month < y.dateBuilt.month or x.dateBuilt.day < y.dateBuilt.day or x.id < y.id end)
end

local findPreviewsByMarker = function(pos, r)
    return function(con)
        return function(params)
            return pipe.new
                * game.interface.getEntities({pos = {pos.x, pos.y}, radius = r})
                * pipe.map(game.interface.getEntity)
                * pipe.filter(function(data) return data.fileName and string.match(data.fileName, con) and data.params.showPreview and data.params.overrideGr == params.overrideGr end)
        end
    end
end

local livetext = livetext("lato", false, "CF2F2F2")

tdpp.updatePreview = function(models, groundFaces, radius, length, slopeA, slopeB, guideline, order)
    local radius2String = function(r) return abs(r) > 1e6 and (r > 0 and "+∞" or "-∞") or tostring(floor(r * 10) * 0.1) end
    
    local fPos = function(ref)
        return function(w)
            return coor.transX(-0.5 * w) * coor.rotX(-pi * 0.5) * coor.rotZ((radius > 0 and -0.5 or 0.5) * pi) * coor.transZ(3)
                * coor.rotZ(ref) * coor.trans(guideline:pt(ref):withZ(0))
        end
    end
    local rtext = livetext(5, 0)("R" .. radius2String(radius))(fPos(guideline.mid))
    local ltext = livetext(5, -1)("L" .. tostring(floor(length * 10) * 0.1))(fPos(guideline.mid))
    local sAtext = livetext(2.5, -0.5)(" " .. tostring(floor(slopeA * 10000) * 0.1) .. "‰ ")(function(w) return fPos(guideline.inf)(0) end)
    local sBtext = livetext(2.5, -0.5)(" " .. tostring(floor(slopeA * 10000) * 0.1) .. "‰ ")(function(w) return fPos(guideline.sup)(2 * w) end)
    return pipe.new * {
        models = pipe.new + ltext + rtext + sAtext + sBtext + models,
        terrainAlignmentLists = {{type = "EQUAL", faces = {}}},
        groundFaces = groundFaces
    }
end

local retriveInfo = function(info)
    if (info) then
        return {
            radius = tonumber(info:match("(%d+)")),
        }
    else
        return {}
    end
end

local function straightResult(posS, posE)
    local length = (posE - posS):length()
    return (length > 1) and {
        f = 1,
        radius = tdp.infi,
        length = length,
        vec = (posE - posS):normalized(),
        pos = posS
    }
end

local function findCircle(posS, posE, vecS, vecE, r, inverted)
    local lnS = line.byVecPt(vecS, posS)
    local lnE = line.byVecPt(vecE, posE)
    local x = lnS - lnE
    
    if (not x) then return nil end

    local dXS = (x - posS):length()
    local dXE = (x - posE):length()
    
    if (abs(dXS / dXE - 1) < 0.005) then
        local lnPS = line.pend(lnS, posS)
        local lnPE = line.pend(lnE, posE)
        local o = lnPS - lnPE

        if (not o) then return nil end
        
        local vecOS = o - posS
        local vecOE = o - posE
        local radius = vecOS:length()
        local rad = atan2(vecOS:normalized():cross(vecOE:normalized()), vecOS:normalized():dot(vecOE:normalized()))
        local result = pipe.new
        if (not inverted and r and radius > r) then
            local o = o + (x - o) * (1 - r / radius)
            local lnPS = line.pend(lnS, o)
            local lnPE = line.pend(lnE, o)
            local posS = lnPS - lnS
            local posE = lnPE - lnE
            local length = abs(rad * r)
            local f = rad > 0 and 1 or -1
            return {
                f = inverted and f or -f,
                radius = r,
                length = inverted and (radius * pi * 2 - length) or length,
                rad = abs(rad),
                o = o:withZ(posS.z),
                vec = vecS,
                pos = posS
            }, posS, posE, true, true
        else
            local length = abs(rad * radius)
            local f = rad > 0 and 1 or -1
            return {
                f = inverted and f or -f,
                radius = radius,
                length = inverted and (radius * pi * 2 - length) or length,
                rad = abs(rad),
                o = o:withZ(posS.z),
                vec = vecS,
                pos = posS
            }, posS, posE, false, false
        end
    else
        if (inverted) then
            if (dXS > dXE) then
                local ret, posS, posE, extS, _ = findCircle(posS, posE + vecE * (dXS - dXE), vecS, vecE, r, true)
                return ret, posS, posE, extS, true
            else
                local ret, posS, posE, _, extE = findCircle(posS + vecS * (dXE - dXS), posE, vecS, vecE, r, true)
                return ret, posS, posE, true, extE
            end
        else
            if (dXS > dXE) then
                local ret, posS, posE, _, extE = findCircle(posS + vecS * (dXS - dXE), posE, vecS, vecE, r)
                return ret, posS, posE, true, extE
            else
                local ret, posS, posE, extS, _ = findCircle(posS, posE + vecE * (dXE - dXS), vecS, vecE, r)
                return ret, posS, posE, extS, true
            end
        end
    end
end

-- local split = function(c, n) -- May be useful some day
--     local dRad = c.rad / n
--     local mRot = quat.byVec(coor.xyz(1, 0, 0), c.pos - c.o):mRot()
--     return pipe.new * func.seq(0, n - 1) * pipe.map(function(i)
--         local mRotVec = quat.byVec(coor.xyz(cos(c.f * i * dRad), sin(c.f * i * dRad), 0), coor.xyz(1, 0, 0)):mRot()
--         local nPt = coor.xyz(c.radius, 0, 0) .. (mRotVec * mRot * coor.trans(c.o))
--         local nVec = c.vec .. mRotVec
--         return func.with(c, {
--             length = c.length / n,
--             rad = dRad,
--             vec = nVec,
--             pos = nPt
--         })
--     end)
-- end
local function solve(s, e, r)
    local posS, rotS, scaleS = coor.decomposite(s.transf)
    local posE, rotE, scaleE = coor.decomposite(e.transf)
    local vecS = coor.xyz(1, 0, 0) .. rotS
    local vecE = coor.xyz(1, 0, 0) .. rotE

    posS = posS:withZ(0)
    posE = posE:withZ(0)
    vecS = vecS:withZ(0):normalized()
    vecE = vecE:withZ(0):normalized()
    -- Work on horizon plan, recalculate Z at last
    local lnS = line.byVecPt(vecS, posS)
    local lnE = line.byVecPt(vecE, posE)
    local m = (posE + posS) * 0.5
    local vecES = posE - posS
    local x = lnS - lnE

    if (x) then
        local vecXS = x - posS
        local vecXE = x - posE
        
        local u = vecXS:length()
        local v = vecXE:length()
        
        local co = vecXS:normalized():dot(vecXE:normalized())
        if (vecXE:dot(vecE) > 0 and vecXS:dot(vecS) > 0) then
            local ret, posCS, posCE = findCircle(posS, posE, vecS, vecE, r)
            return pipe.new
                / straightResult(posS, posCS)
                / ret
                / straightResult(posCE, posE)
        elseif (vecXE:dot(vecE) < 0 and vecXS:dot(vecS) < 0) then
            local ret, posCS, posCE = findCircle(posS, posE, vecS, vecE, r, true)
            return pipe.new
                / straightResult(posS, posCS)
                / ret
                / straightResult(posCE, posE)
        elseif ((vecXS:dot(vecS) < 0 and vecXE:dot(vecE) > 0)) then
            local mRot = coor.rotZ(0.5 * pi)
            local vecOS = coor.xyz(-vecS.y, vecS.x, 0) * (vecS:cross(vecE).z < 0 and 1 or -1)
            local vecOE = coor.xyz(-vecE.y, vecE.x, 0) * (vecS:cross(vecE).z < 0 and 1 or -1)
            local a = posS - posE
            local b = vecOS - vecOE
            local ab = a:dot(b)
            local radius = (ab + sqrt(ab * ab + 4 * a:dot(a) - a:length2() * b:length2())) / (4 - b:length2())
            local oS = posS + vecOS * radius
            local oE = posE + vecOE * radius
            local m = (oS + oE) * 0.5
            local vecP = (oE - oS):normalized()
            local vecT = coor.xyz(-vecP.y, vecP.x, 0) * (vecS:cross(vecE).z < 0 and 1 or -1)
            local ret1, posCS1, posCE1 = findCircle(posS, m, vecS, vecT, r)
            local ret2, posCS2, posCE2 = findCircle(m, posE, vecT, vecE, r)
            return pipe.new
                / straightResult(posS, posCS1)
                / ret1
                / straightResult(posCE1, posCS2)
                / ret2
                / straightResult(posCE2, posE)
        elseif ((vecXE:dot(vecE) < 0 and vecXS:dot(vecS) > 0)) then
            return solve(e, s, r, not isRev), true
        end
    else
        local lnPenE = line.pend(lnE, posE)
        local posP = lnPenE - lnS
        local vecEP = posE - posP
        if (vecEP:length() < 1e-3) then
            local length = vecES:length()
            return pipe.new /
                {
                    f = 1,
                    radius = tdp.infi,
                    length = length,
                    pos = posS,
                    vec = vecS
                }
        else
            if (vecE:dot(vecS) > 0) then
                local lnPS = line.pend(lnS, posS)
                local x = lnPS - lnE
                local vecXE = x - posE
                if (vecXE:dot(vecE) > 0) then
                    local r = (x - posS):length() * 0.5
                    return pipe.new
                        /
                        {
                            f = vecES:cross(vecS).z > 0 and 1 or -1,
                            radius = r,
                            length = r * pi,
                            vec = vecS,
                            pos = posS
                        }
                        / straightResult(x, posE)
                else
                    return solve(e, s, r), true
                end
            else
                local mRot = quat.byVec(vecS, vecES:normalized()):mRot()
                local vecT = vecES .. mRot
                local lnT = line.byVecPt(vecT, m)
                local ret1, posCS1, posCE1 = findCircle(posS, m, vecS, -vecT, r)
                local ret2, posCS2, posCE2 = findCircle(m, posE, vecT, vecE, r)
                if (ret1 and ret2) then
                    return pipe.new
                        / straightResult(posS, posCS1)
                        / ret1
                        / straightResult(posCE1, posCS2)
                        / ret2
                        / straightResult(posCE2, posE)
                else
                    local length = vecES:length()
                    return pipe.new /
                        {
                            f = 1,
                            radius = tdp.infi,
                            length = length,
                            pos = posS,
                            vec = vecES
                        }
                end
            end
        end
    end
end

tdpp.solve = solve

local retriveParams = function(markers, con, r)
    local s, e = unpack(markers)
    
    local posS, _, _ = coor.decomposite(s.transf)
    local posE, _, _ = coor.decomposite(e.transf)

    local pos = (posE + posS) * 0.5
    
    local findPreviewsByMarker = function(params)
        return pipe.new
            * game.interface.getEntities({pos = {pos.x, pos.y}, radius = (posE - posS):length()})
            * pipe.map(game.interface.getEntity)
            * pipe.filter(function(data) return data.fileName and string.match(data.fileName, con) and data.params.showPreview and data.params.overrideGr == params.overrideGr end)
    end
    
    local results, isRev = solve(s, e, r)
    local results = results * pipe.filter(pipe.noop())
    
    local totalLength = results * pipe.fold(0, function(sum, r) return sum + r.length end)
    
    if (isRev) then
        posE, posS = posS, posE
    end
    
    local results = results * pipe.fold({totalLength, pipe.new * {}}, function(result, seg)
        local restLength, results = unpack(result)
        return {
            restLength - seg.length,
            results / func.with(seg, {
                pos = seg.pos:withZ(posE.z + restLength / totalLength * (posS.z - posE.z)),
                vec = seg.vec:withZ(0):normalized(),
                slopeA = (posE - posS).z / totalLength,
                slopeB = (posE - posS).z / totalLength,
                percentA = 1 - restLength / totalLength,
                percentB = 1 - (restLength - seg.length) / totalLength
            })
        }
    end) * pipe.select(2)
    
    return findPreviewsByMarker, results
end

local refineParams = function(params, markers, con)
    local info = retriveInfo(
        markers
        * pipe.filter(function(m) return string.find(m.name, "#", 0, true) == 1, 1 end)
        * pipe.map(pipe.select("name")) * pipe.select(1)
    )
    local findPreviewsByMarker, results = retriveParams(markers, con, info.radius or nil)
    return findPreviewsByMarker, results
end

local findPreviewInstance = function(params)
    return pipe.new
        * game.interface.getEntities({pos = game.gui.getTerrainPos(), radius = 9999})
        * pipe.map(game.interface.getEntity)
        * pipe.filter(function(data) return data.params and data.params.seed == params.seed end)
end

tdpp.updatePlanner = function(params, markers, con)
    if (params.override == 1) then
        local findPreviewsByMarker, results = refineParams(params, markers, con)
        local con = "track_design_patterns/" .. con
        local nbTracks = markers[1].params.nbTracks
        local pre = findPreviewsByMarker(params)
        local _ = pre * pipe.map(pipe.select("id")) * pipe.forEach(game.interface.bulldoze)
                
        local transf = quat.byVec(coor.xyz(0, 1, 0), (results[1].vec):withZ(0)):mRot() * coor.trans(results[1].pos)
        local vecRef, rotRef, _ = coor.decomposite(transf)
        local iRot = coor.inv(cov(rotRef))
        
        local previewParams = func.with(station.pureParams(params),
            {
                showPreview = true,
                overrideMeta = func.mapi(results, function(r, i)
                        
                        local transf = quat.byVec(coor.xyz(0, 1, 0), (r.vec):withZ(0)):mRot() * coor.trans(r.pos)
                        local vec, rot, _ = coor.decomposite(transf)

                        return {
                            order = i,
                            nbTracks = nbTracks,
                            radius = r.f * r.radius,
                            length = r.length,
                            slopeA = r.slopeA,
                            slopeB = r.slopeB,
                            percentA = r.percentA,
                            percentB = r.percentB,
                            m = iRot * rot * coor.trans((vec - vecRef) .. iRot),
                            transf = transf,
                            isFirst = i == 1,
                            isLast = i == #results
                        }
                end)
            })
        local transf = quat.byVec(coor.xyz(0, 1, 0), (results[1].vec):withZ(0)):mRot() * coor.trans(results[1].pos)
        local id = game.interface.buildConstruction(
            con,
            previewParams,
            transf
        )
        game.interface.setPlayer(id, game.interface.getPlayer())
    
    else
        local pre = #markers == 2 and retriveParams(markers, con)(params) or findPreviewInstance(params)
        if (params.override == 2) then
            if (pre and #pre > 0) then
                local _ = markers * pipe.map(function(m) return m.id end) * pipe.forEach(game.interface.bulldoze)
                func.forEach(pre, function(pre)
                    game.interface.upgradeConstruction(
                        pre.id,
                        pre.fileName,
                        func.with(station.pureParams(pre.params),
                            {
                                override = 2,
                                showPreview = false,
                                isBuild = true,
                            })
                )
                end)
            end
        elseif (params.override == 3) then
            local _ = pre * pipe.map(pipe.select("id")) * pipe.forEach(game.interface.bulldoze)
        end
    end
end


return tdpp
