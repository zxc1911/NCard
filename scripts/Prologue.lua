-- 游戏开场与序章任务状态机

local Prologue = {}

local INTRO_LINES = {
    {
        speaker = "母亲 · 塞拉",
        text = "洛恩……该起床了。",
        duration = 3.4,
    },
    {
        speaker = "母亲 · 塞拉",
        text = "今天是爬塔的日子。你盼了这么久，可别错过第一声晨钟。",
        duration = 5.4,
    },
    {
        speaker = "母亲 · 塞拉",
        text = "准备好以后，去教堂见主教。他会告诉你候选者应当知道的事。",
        duration = 5.8,
    },
}

function Prologue.Create()
    return {
        phase = "title",
        phaseTimer = 0.0,
        lineIndex = 1,
        lineTimer = 0.0,
        quest = "find_mother",
        motherTalked = false,
        gravityCardCollected = false,
        invitationCollected = false,
        homeRevealed = false,
    }
end

function Prologue.Begin(state)
    if state.phase ~= "title" then return false end
    state.phase = "intro"
    state.phaseTimer = 0.0
    state.lineIndex = 1
    state.lineTimer = 0.0
    print("[Prologue] Title accepted; black-screen opening started")
    return true
end

function Prologue.Update(state, dt)
    if state.phase == "intro" then
        local line = INTRO_LINES[state.lineIndex]
        state.lineTimer = state.lineTimer + dt
        if state.lineTimer >= line.duration then
            state.lineIndex = state.lineIndex + 1
            state.lineTimer = 0.0
            if state.lineIndex > #INTRO_LINES then
                state.phase = "reveal"
                state.phaseTimer = 0.0
                state.homeRevealed = true
                print("[Prologue] Opening narration complete; revealing home")
                return "reveal_home"
            end
        end
    elseif state.phase == "reveal" then
        state.phaseTimer = state.phaseTimer + dt
        if state.phaseTimer >= 1.35 then
            state.phase = "gameplay"
            state.phaseTimer = 0.0
            print("[Prologue] Gameplay started")
            return "gameplay_started"
        end
    end
    return nil
end

function Prologue.IsTitle(state)
    return state.phase == "title"
end

function Prologue.IsIntro(state)
    return state.phase == "intro"
end

function Prologue.IsGameplayReady(state)
    return state.phase == "gameplay"
end

function Prologue.GetIntroLine(state)
    if state.phase ~= "intro" then return nil end
    return INTRO_LINES[state.lineIndex]
end

function Prologue.GetIntroLineAlpha(state)
    if state.phase ~= "intro" then return 0.0 end
    local line = INTRO_LINES[state.lineIndex]
    local fadeIn = math.min(1.0, state.lineTimer / 0.55)
    local fadeOut = math.min(1.0, math.max(0.0, line.duration - state.lineTimer) / 0.7)
    return math.min(fadeIn, fadeOut)
end

function Prologue.GetRevealAlpha(state)
    if state.phase ~= "reveal" then return 0.0 end
    return math.max(0.0, 1.0 - state.phaseTimer / 1.35)
end

function Prologue.CompleteMotherTalk(state)
    if state.motherTalked then return false end
    state.motherTalked = true
    state.quest = state.gravityCardCollected and "find_invitation" or "find_gravity_card"
    print("[Prologue] Mother dialogue complete; next home objective selected")
    return true
end

function Prologue.CollectGravityCard(state)
    if state.gravityCardCollected then return false end
    state.gravityCardCollected = true
    if state.motherTalked then state.quest = "find_invitation" end
    print("[Prologue] Pope cards collected; invitation room awaits mother dialogue")
    return true
end

function Prologue.CanEnterInvitationRoom(state)
    return state.motherTalked and state.gravityCardCollected
end

function Prologue.CollectInvitation(state)
    if state.invitationCollected then return false end
    state.invitationCollected = true
    state.quest = "go_church"
    print("[Prologue] Tower invitation collected")
    return true
end

function Prologue.GetQuestText(state)
    if state.quest == "find_mother" then
        return "序章 · 爬塔之日\n下楼找到母亲"
    elseif state.quest == "find_gravity_card" then
        return "序章 · 出发准备\n取得教皇的礼物"
    elseif state.quest == "find_invitation" then
        return "序章 · 出发准备\n用两张法则卡取得窗台上的邀请函"
    end
    return "序章 · 教会的召唤\n带着邀请函前往教会找教皇"
end

return Prologue
