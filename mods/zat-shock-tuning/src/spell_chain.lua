-- Opt-in propagation for Chain Lightning casts and individual Eternal Arc pulses.
local B=require("impact_builder")
local propagation=require("chain_propagation")
local M={}
function M.plan(settings,radius,cast,api,arc_items)
    local label=arc_items and "arc_lightning.propagation" or "chain_lightning.propagation"
    if type(settings)=="table" and settings.spread_delay_ms==nil then settings.spread_delay_ms=250 end
    api.keys(settings,{enabled=true,targets_per_spread=true,max_jumps=true,spread_delay_ms=true},label)
    if type(settings.enabled)~="boolean" then api.fail(label..".enabled must be true or false") end
    api.number(settings.targets_per_spread,"uint32",label..".targets_per_spread")
    api.number(settings.max_jumps,"uint32",label..".max_jumps")
    api.number(settings.spread_delay_ms,"uint32",label..".spread_delay_ms")
    if not settings.enabled then return end
    local guid=arc_items and "b8326171-b67a-41c7-8c0b-b30750d8ff7a" or "e28f0d79-e2fe-46ba-8d82-9ba368cb30c7"
    local p=api.resource(guid,"keen::ImpactProgram")
    local signature={}
    for _,e in ipairs(p.dataLayout) do signature[#signature+1]=string.pack("<I4I4I4I4I4",
        e.name.value,e.configId.value,e.type.value,e.size,e.offsetInBytes)..e.dbgName..string.char(0) end
    if #p.code~=(arc_items and 473 or 477)
        or B.hash(p.code,"<I4")~=(arc_items and 3696472098 or 1582077647)
        or #p.data~=(arc_items and 1329 or 1361)
        or B.hash(p.data,"B")~=(arc_items and 1345229789 or 1813197745)
        or #p.dataLayout~=80
        or B.fnv(table.concat(signature))~=(arc_items and 3825030913 or 3679545508) or p.stackSize~=256
        or #p.codeShutdown~=1 or p.codeShutdown[1]~=30 or #p.queryCallIds~=0
        or #p.usedStreams~=1 or p.usedStreams[1]~="OnCollision"
        or p.id.value~=(arc_items and 3907315843 or 826044855) or p.programGuid~=guid then
        api.fail("Spell chain: conflicting or unsupported native program")
    end
    local namespace=arc_items and "ZatArcChain" or "ZatSpellChain"
    local config_id=B.fnv(namespace..".Enabled")
    local sources=arc_items or {cast}
    for _,source in ipairs(sources) do
        for _,entry in ipairs(source.impactValues.simple) do
            if entry.value.configId.value==config_id then api.fail(label..": conflicting impact config") end
        end
    end
    local b=B.new(p,api,namespace)
    -- Default false in the shared program. Only the chosen player casting
    -- sequence supplies true; other native sequences keep the original flow.
    b.bool("enabled",false,config_id)
    local profile={key="spell",config={targets_per_spread=settings.targets_per_spread,
        max_jumps=settings.max_jumps,spread_radius=radius,chance_percent=100,spread_delay_ms=settings.spread_delay_ms}}
    propagation.prepare(b,{profile},api)
    local pre=#b.code
    b.load("enabled");b.branch(10,"capture_done")
    propagation.capture(b,"Get_targetlock::targetId","GetRoot::entityId")
    b.mark("capture_done");b.emit(8,arc_items and 93 or 98) -- retain the original timer pop and initial damage.
    local post=#b.code
    b.load("enabled");b.branch(9,arc_items and "arc_start" or "spell_start");b.emit(8,arc_items and 168 or 143)
    -- The Arc success continuation has a timer result to pop. The blocked
    -- path still goes straight to its original native destination.
    if arc_items then b.mark("arc_start");b.emit(27) end
    local context={initial="Get_targetlock::targetId",root="GetRoot::entityId",
        damage_args=function()
            return {false,"true",false,false,false,false,false,"Material::valueId",
                "WeaponCategory::value","AttackCategory::value","Damage::value","hitReactionType::value",
                "PushBackStrength::value","DamageScaleAttribute::value",false,false,"NoiseRange::value",
                false,"AttackMod::value","HitDirection::value","impact_nodes.ForEachCollisionInStream::normal",
                "position","best","Self1::entityId","was_blocked"}
        end,
        after_hit=function()
            b.done("SpawnEntity",{false,false,"best",false,false,false,false,"StaminaDamageImpactTemplate::value",
                "SpawnStaminaDamageImpact1::copyParentFaction","SpawnStaminaDamageImpact1::copyParentLevel",
                "SpawnStaminaDamageImpact1::addDespawnLink","SpawnStaminaDamageImpact1::breakImpactHierarchy",false})
        end}
    propagation.emit(b,profile,context)
    propagation.finish(b);b.emit(29,30)
    b.finish()
    b.code[arc_items and 90 or 95]=pre
    b.code[arc_items and 165 or 277]=post
    return {label=arc_items and "arc_lightning.nearest_fanout_program" or "chain_lightning.nearest_fanout_program",before=0,after=1,apply=function()
        for _,source in ipairs(sources) do
            local values=B.array(source.impactValues.simple)
            local guid="8254bf47-cc20-4ca7-8514-28ae6cc1811d"
            values[#values+1]={type="keen::impact::BoolImpactConfig",value={locaTag=values[1].value.locaTag,isSigned=false,
                valueFormat="Normal",id=guid,configId={value=config_id},type={value=3365180733},configGuid=guid,
                objectId="bfe73b78-d32f-4d4f-afdc-2d3801289b15",value=true}}
            source.impactValues.simple=values
        end
        print("[Zat Shock Tuning] Spell frontier native storage: "..b.capacity.." pending spreaders; slots are reused")
        b.apply()
    end}
end
return M
