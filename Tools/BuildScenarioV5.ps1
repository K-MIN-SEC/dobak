$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$resourcePath = Join-Path $root "Assets/Resources"
$source = Import-Csv -LiteralPath (Join-Path $resourcePath "ScenarioV3.csv")
$sourceReplies = Import-Csv -LiteralPath (Join-Path $resourcePath "ScenarioV3Replies.csv")
$replyByChoice = @{}
foreach ($reply in $sourceReplies) {
    if ($reply.choice_id) { $replyByChoice[$reply.choice_id] = $reply.reply_text }
}

$columns = @(
    "schema_version", "scene_id", "line_id", "arc", "day", "time_window", "trigger", "condition",
    "priority", "once_scope", "sequence", "speaker", "contact", "delivery", "portrait", "text",
    "choice_a_id", "choice_a_text", "choice_a_reply", "choice_a_effects", "choice_a_next",
    "choice_b_id", "choice_b_text", "choice_b_reply", "choice_b_effects", "choice_b_next",
    "choice_c_id", "choice_c_text", "choice_c_reply", "choice_c_effects", "choice_c_next",
    "enter_effects", "auto_next", "purpose"
)

function New-ScenarioRow {
    param(
        [string]$Scene, [string]$Line, [string]$Arc, [string]$Day, [string]$Time,
        [string]$Trigger, [string]$Condition, [int]$Priority, [string]$Scope, [int]$Sequence,
        [string]$Speaker, [string]$Contact, [string]$Delivery, [string]$Portrait, [string]$Text,
        [string]$AId = "", [string]$AText = "", [string]$AReply = "", [string]$AEffects = "", [string]$ANext = "",
        [string]$BId = "", [string]$BText = "", [string]$BReply = "", [string]$BEffects = "", [string]$BNext = "",
        [string]$CId = "", [string]$CText = "", [string]$CReply = "", [string]$CEffects = "", [string]$CNext = "",
        [string]$Effects = "", [string]$Next = "", [string]$Purpose = ""
    )
    [pscustomobject][ordered]@{
        schema_version = "5"; scene_id = $Scene; line_id = $Line; arc = $Arc; day = $Day
        time_window = $Time; trigger = $Trigger; condition = $Condition; priority = [string]$Priority
        once_scope = $Scope; sequence = [string]$Sequence; speaker = $Speaker; contact = $Contact
        delivery = $Delivery; portrait = $Portrait; text = $Text
        choice_a_id = $AId; choice_a_text = $AText; choice_a_reply = $AReply; choice_a_effects = $AEffects; choice_a_next = $ANext
        choice_b_id = $BId; choice_b_text = $BText; choice_b_reply = $BReply; choice_b_effects = $BEffects; choice_b_next = $BNext
        choice_c_id = $CId; choice_c_text = $CText; choice_c_reply = $CReply; choice_c_effects = $CEffects; choice_c_next = $CNext
        enter_effects = $Effects; auto_next = $Next; purpose = $Purpose
    }
}

function Convert-SourceRow($row) {
    $result = [ordered]@{}
    foreach ($column in $columns) { $result[$column] = "" }
    foreach ($property in $row.PSObject.Properties) {
        if ($result.Contains($property.Name)) { $result[$property.Name] = $property.Value }
    }
    $result.schema_version = "5"
    if ($result.day -eq "1..14") { $result.day = "1..5" }
    elseif ($result.day -eq "2..14") { $result.day = "2..5" }
    elseif ($result.day -eq "1..13") { $result.day = "1..4" }
    foreach ($slot in "a", "b", "c") {
        $choiceId = $result["choice_${slot}_id"]
        if ($choiceId -and $replyByChoice.ContainsKey($choiceId)) {
            $result["choice_${slot}_reply"] = $replyByChoice[$choiceId]
        }
    }
    [pscustomobject]$result
}

$coreScenes = @(
    "collapse_check_stable", "collapse_check_gamble", "collapse_check_debt", "bedtime_cue",
    "gamble_1", "gamble_2", "gamble_3", "gamble_4", "gamble_5", "gamble_6", "gamble_7", "gamble_8",
    "after_gamble_1_router", "late_first_gamble_return", "gamble_repeat_loss", "gamble_no_funds",
    "gamble_no_funds_stop", "gamble_no_funds_exhausted", "borrow_choice", "borrow_choice_minjae",
    "borrow_defer_night", "borrow_morning_cue", "borrow_morning_minjae_cue", "borrow_prepare_mom",
    "borrow_prepare_seojun", "mom_loan_message", "mom_loan_response", "seojun_loan_message",
    "seojun_loan_response", "minjae_loan_offer", "minjae_loan_rejected", "minjae_loan_accepted",
    "sys_borrow_late_morning", "sys_late_gamble_morning", "sys_late_gamble_morning_weekend"
)

$rows = [System.Collections.Generic.List[object]]::new()
foreach ($sourceRow in $source) {
    if ($sourceRow.day -eq "1" -or $coreScenes -contains $sourceRow.scene_id) {
        $row = Convert-SourceRow $sourceRow
        switch ($row.line_id) {
            "d1_intro_01" { $row.enter_effects = "clock:set=07:00|cash:set=150000|debt:set=0|flag.gambling_started:set=false" }
            "d1_intro_goal_02" { $row.text = "내가 떨어뜨린 거라 부모님께 또 부탁하기도 애매했다. 통장에 모아 둔 돈은 15만 원." }
            "d1_intro_goal_03" { $row.text = "이번 주말 알바를 이틀 다 나가면 10만 원을 더 모을 수 있다. 그러면 수리비 25만 원을 채울 수 있다. 괜히 다른 방법 찾지 말고 일정부터 지키자." }
            "d1_school_01" { $row.text = "다음 주 화요일에 조별 발표할 거야. 주제는 온라인 광고랑 확률 표현이고." }
            "d1_school_02" { $row.text = "다음 주에 바로 조별 발표라니. 누구랑 같은 조지?" }
            "d1_school_05" { $row.text = "월요일까지 상담 번호랑 사례를 정리해 줄래? 나는 예방치유원 자료를 볼게." }
            "d1_school_09" { $row.text = "응. 내가 찾은 자료는 월요일 아침에 보내둘게. 주말 잘 보내." }
            "d1_school_10" { $row.text = "그래. 월요일에 보자." }
            "d1_school_missed_message_01" {
                $row.text = "오늘 학교 안 왔더라. 우리 둘이 같은 조 됐어. 다음 주 화요일에 온라인 광고랑 확률 표현으로 발표한대."
                $row.enter_effects = "flag.project_introduced:set=true"
            }
            "d1_school_missed_message_02" { $row.text = "월요일까지 상담 번호랑 사례를 정리해 줄래? 나는 예방치유원 자료를 볼게." }
            "d1_minjae_invite_04" { $row.text = "수리비까지 남은 돈은 10만 원이다. 주말 이틀을 다 일하면 채울 수 있지만, 가입 보너스로 시작하면 더 빨라질지도 모른다.... 아니, 이런 생각부터 이상한 건가." }
            "d1_minjae_invite_02" { $row.text = "신규 가입하면 무료 포인트 줌. 오늘 자정 전엔 추천 보너스도 두 배래." }
            "d1_evening_02" { $row.text = "오늘은 여기까지 하자. 내일 알바도 있으니까 씻고 잘 준비나 해야겠다." }
            "collapse_check_stable_01" { $row.condition = "schedule_failures>=3|counter.school_absences>=3|counter.job_failures>=2;counter.gamble_sessions<3;debt=0" }
            "collapse_check_gamble_01" { $row.condition = "schedule_failures>=3|counter.school_absences>=3|counter.job_failures>=2;counter.gamble_sessions>=3;debt=0" }
            "collapse_check_debt_01" { $row.condition = "schedule_failures>=3|counter.school_absences>=3|counter.job_failures>=2;counter.gamble_sessions>=3;debt>0" }
            "sys_late_gamble_morning_01" { $row.condition = "flag.gambled_late=true;flag.borrow_deferred!=true;day!=2;day!=3" }
            "sys_late_gamble_morning_02" { $row.condition = "flag.gambled_late=true;flag.borrow_deferred!=true;day!=2;day!=3" }
            "sys_late_gamble_morning_weekend_01" { $row.condition = "flag.gambled_late=true;flag.borrow_deferred!=true;day=2|day=3" }
            "sys_late_gamble_morning_weekend_02" { $row.condition = "flag.gambled_late=true;flag.borrow_deferred!=true;day=2|day=3" }
        }
        $rows.Add($row)
    }
}

$rows.Add((New-ScenarioRow "d1_school_missed_message" "d1_school_missed_message_03" "school" "1" "night" "school_missed" "" 175 "day" 3 "Protagonist" "서연" "message" "" "미안해. 오늘 연락도 못 했어. 월요일까지 상담 번호랑 사례 정리해서 보낼게." -Effects "relation.seoyeon:add=-1"))

# Day 2: Saturday, first job shift and first direct schedule conflict.
$rows.Add((New-ScenarioRow "v5_d2_start" "v5_d2_start_01" "main" "2" "7:00" "day_start" "flag.late_wake_today!=true" 220 "day" 1 "Protagonist" "나" "narration" "" "토요일 아침. 오늘은 카페 첫 근무가 있는 날이다." -Purpose "첫 주말 근무를 일정의 중심에 둔다."))
$rows.Add((New-ScenarioRow "v5_d2_start" "v5_d2_start_02" "main" "2" "7:00" "day_start" "" 220 "day" 2 "Protagonist" "나" "dialogue" "" "오늘 일당 5만 원을 받으면 수리비까지 5만 원만 남는다. 늦지 않게 출발하자." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d2_minjae" "v5_d2_minjae_01" "gambling" "2" "morning" "day_start" "" 180 "day" 1 "Minjae" "민재" "message" "minjae_default" "오늘 알바지? 하루 종일 일해서 5만 원 받느니 어제 보낸 앱이 훨씬 빠르다니까." "v5_d2_reply_job" "알바부터 갈 거야." "오늘은 알바부터 갈 거야. 끝나고 내가 정할게." "counter.refusals:add=1" "" "v5_d2_reply_later" "끝나고 확인해 볼게." "알바 끝나고 확인해 볼게. 지금은 늦으면 안 돼." "gamble:offer" "" -Purpose "도박 여부는 메시지 선택이 아니라 일정 완료 뒤 앱에서 결정한다."))
$rows.Add((New-ScenarioRow "v5_d2_job" "v5_d2_job_01" "job" "2" "job" "job_complete" "" 190 "game" 1 "CafeManager" "점장님" "dialogue" "manager_default" "첫날이니까 주문보다 정리부터 익혀. 모르는 건 바로 물어보고."))
$rows.Add((New-ScenarioRow "v5_d2_job" "v5_d2_job_02" "job" "2" "job" "job_complete" "" 190 "game" 2 "Protagonist" "나" "narration" "" "정신없이 움직이다 보니 어느새 마감 시간이었다."))
$rows.Add((New-ScenarioRow "v5_d2_job" "v5_d2_job_03" "job" "2" "job" "job_complete" "" 190 "game" 3 "CafeManager" "점장님" "dialogue" "manager_default" "오늘 일당 5만 원은 넣어뒀어. 내일도 같은 시간에 보자." -Effects "counter.job_attendance:add=1|relation.manager:add=1" -Purpose "첫 근무와 정상 수입을 보여 준다."))
$rows.Add((New-ScenarioRow "v5_d2_job_missed" "v5_d2_job_missed_01" "job" "2" "afternoon" "job_missed" "" 190 "day" 1 "CafeManager" "점장님" "message" "manager_worried" "오늘 첫 출근인데 연락도 없이 안 왔네. 무슨 일 있니?" "v5_d2_missed_apology" "죄송하다고 답한다." "죄송해요. 시간을 놓쳤어요. 내일은 꼭 먼저 연락드릴게요." "relation.manager:add=-2" "" -Purpose "첫 결근을 즉시 관계 결과로 돌려준다."))
$rows.Add((New-ScenarioRow "v5_d2_evening_done" "v5_d2_evening_done_01" "main" "2" "evening" "evening_fill" "schedule.job=complete" 90 "day" 1 "Protagonist" "나" "overlay" "" "첫 근무를 마쳤다. 피곤하지만 오늘 번 돈이 통장에 들어온 걸 보니 계획이 조금 선명해졌다." -Effects "clock:set=21:00"))
$rows.Add((New-ScenarioRow "v5_d2_evening_missed" "v5_d2_evening_missed_01" "main" "2" "evening" "evening_fill" "schedule.job=missed" 89 "day" 1 "Protagonist" "나" "overlay" "" "오늘 몫 5만 원이 비었다. 내일 근무까지 놓치면 수리비 계획을 다시 세워야 한다." -Effects "clock:set=21:00"))

# Day 3: Sunday, second job shift and escalating temptation.
$rows.Add((New-ScenarioRow "v5_d3_start" "v5_d3_start_01" "main" "3" "7:00" "day_start" "flag.late_wake_today!=true" 220 "day" 1 "Protagonist" "나" "narration" "" "일요일 아침. 오늘 카페 근무까지 마치면 이번 주말 일정은 끝난다."))
$rows.Add((New-ScenarioRow "v5_d3_start" "v5_d3_start_02" "main" "3" "7:00" "day_start" "" 220 "day" 2 "Protagonist" "나" "dialogue" "" "어제 결과가 어떻든 출근 시간은 기다려 주지 않는다. 먼저 카페에 가자." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d3_minjae_none" "v5_d3_minjae_none_01" "gambling" "3" "morning" "day_start" "counter.gamble_sessions=0" 182 "day" 1 "Minjae" "민재" "message" "minjae_default" "아직도 안 해봤어? 보너스 없어지기 전에 한 번만 눌러 봐." "v5_d3_none_reply" "오늘도 알바부터 간다." "오늘도 알바부터 갈 거야. 계속 재촉하지 마." "counter.refusals:add=1" ""))
$rows.Add((New-ScenarioRow "v5_d3_minjae_profit" "v5_d3_minjae_profit_01" "gambling" "3" "morning" "day_start" "counter.gamble_sessions>=1;counter.gamble_sessions<3" 183 "day" 1 "Minjae" "민재" "message" "minjae_default" "전에 바로 돈 들어오는 거 봤잖아. 오늘도 한 번만 하면 수리비 금방 채우겠다." "v5_d3_profit_stop" "번 돈으로 끝낸다." "그때 번 건 운이 좋았던 거야. 오늘은 알바부터 갈게." "counter.refusals:add=1" "" "v5_d3_profit_later" "알바 뒤에 생각한다." "지금은 알바 가야 해. 끝나고 내가 정할게." "gamble:offer" ""))
$rows.Add((New-ScenarioRow "v5_d3_minjae_loss" "v5_d3_minjae_loss_01" "gambling" "3" "morning" "day_start" "counter.gamble_sessions>=3" 184 "day" 1 "Minjae" "민재" "message" "minjae_angry" "지금 멈추면 잃은 돈 그대로잖아. 오늘 흐름 좋다니까 알바 끝나고라도 복구해." "v5_d3_loss_stop" "더 잃기 전에 멈춘다." "잃은 돈 때문에 또 들어가진 않을 거야. 오늘 일정부터 지킬게." "counter.refusals:add=1" "" "v5_d3_loss_later" "알바 뒤에 다시 본다." "일단 알바부터 갈게. 끝나고 다시 생각해 볼게." "gamble:offer" ""))
$rows.Add((New-ScenarioRow "v5_d3_job_good" "v5_d3_job_good_01" "job" "3" "job" "job_complete" "counter.job_attendance>=1" 192 "game" 1 "CafeManager" "점장님" "dialogue" "manager_default" "주말 이틀 다 시간 맞춰 왔네. 오늘 일당까지 넣어뒀어. 수고했다." -Effects "counter.job_attendance:add=1|relation.manager:add=2"))
$rows.Add((New-ScenarioRow "v5_d3_job_return" "v5_d3_job_return_01" "job" "3" "job" "job_complete" "counter.job_attendance=0" 191 "game" 1 "CafeManager" "점장님" "dialogue" "manager_worried" "어제는 걱정했어. 오늘 나온 건 다행이지만 다음에는 늦기 전에 꼭 연락해." -Effects "counter.job_attendance:add=1|relation.manager:add=-1"))
$rows.Add((New-ScenarioRow "v5_d3_job_missed_first" "v5_d3_job_missed_first_01" "job" "3" "afternoon" "job_missed" "counter.job_failures=0" 192 "day" 1 "CafeManager" "점장님" "message" "manager_worried" "오늘 출근하지 않았네. 계속 근무할 생각이 있는지는 알려 줘." "v5_d3_missed_apology" "사과하고 다시 기회를 부탁한다." "죄송해요. 다음 근무 전에는 꼭 먼저 연락드릴게요." "relation.manager:add=-2" ""))
$rows.Add((New-ScenarioRow "v5_d3_job_missed_fired" "v5_d3_job_missed_fired_01" "job" "3" "afternoon" "job_missed" "counter.job_failures>=1" 193 "day" 1 "CafeManager" "점장님" "message" "manager_angry" "두 번 연속 연락 없이 빠졌어. 다음 근무는 당분간 잡기 어렵겠다." "v5_d3_fired_reply" "죄송하다고 답한다." "죄송합니다. 제가 약속을 지키지 못했어요." "relation.manager:add=-3|flag.job_fired:set=true" "" -Purpose "연속 결근을 명확한 해고 결과로 보여 준다."))
$rows.Add((New-ScenarioRow "v5_d3_evening_done" "v5_d3_evening_done_01" "main" "3" "evening" "evening_fill" "schedule.job=complete" 90 "day" 1 "Protagonist" "나" "overlay" "" "주말 근무는 끝났다. 내일은 학교에서 발표 자료를 마무리해야 한다." -Effects "clock:set=21:00"))
$rows.Add((New-ScenarioRow "v5_d3_evening_missed" "v5_d3_evening_missed_01" "main" "3" "evening" "evening_fill" "schedule.job=missed" 89 "day" 1 "Protagonist" "나" "overlay" "" "알바도 수리비 계획도 꼬였다. 그래도 내일 학교와 조별과제까지 놓칠 수는 없다." -Effects "clock:set=21:00"))

# Day 4: Monday, education, project work and the help-or-hide decision.
$rows.Add((New-ScenarioRow "v5_d4_start_stable" "v5_d4_start_stable_01" "main" "4" "7:00" "day_start" "counter.gamble_sessions<3;flag.late_wake_today!=true" 220 "day" 1 "Protagonist" "나" "narration" "" "월요일 아침. 오늘은 학교에서 서연과 발표 자료를 마무리해야 한다." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d4_start_risk" "v5_d4_start_risk_01" "main" "4" "7:00" "day_start" "counter.gamble_sessions>=3;flag.late_wake_today!=true" 221 "day" 1 "Protagonist" "나" "narration" "" "월요일 아침. 잃은 돈과 빌린 돈 생각이 먼저 떠올랐지만 오늘은 학교와 조별과제를 더 미룰 수 없다." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d4_school_stable" "v5_d4_school_stable_01" "school" "4" "school" "school_complete" "counter.gamble_sessions<3" 210 "game" 1 "Teacher" "담임 선생님" "dialogue" "" "오늘은 온라인 도박 광고가 왜 게임처럼 보이는지 살펴볼 거야. 무료 포인트와 보상 연출도 유혹 장치가 될 수 있어."))
$rows.Add((New-ScenarioRow "v5_d4_school_stable" "v5_d4_school_stable_02" "school" "4" "school" "school_complete" "counter.gamble_sessions<3" 210 "game" 2 "Seoyeon" "서연" "dialogue" "seoyeon_default" "우리 자료랑도 딱 맞네. 방과 후에 공부 앱에서 사례랑 대응 방법만 정리하자."))
$rows.Add((New-ScenarioRow "v5_d4_school_stable" "v5_d4_school_stable_03" "school" "4" "school" "school_complete" "counter.gamble_sessions<3" 210 "game" 3 "Protagonist" "나" "dialogue" "" "응. 집에 가서 오늘 안에 끝내고 내일 발표하자." -Effects "tutorial:set=study"))
$rows.Add((New-ScenarioRow "v5_d4_school_risk" "v5_d4_school_risk_01" "school" "4" "school" "school_complete" "counter.gamble_sessions>=3" 211 "game" 1 "Teacher" "담임 선생님" "dialogue" "" "손실을 되찾으려고 돈을 빌리거나 학교와 약속을 미루기 시작했다면 혼자 해결하려 하지 말고 바로 도움을 요청해야 해."))
$rows.Add((New-ScenarioRow "v5_d4_school_risk" "v5_d4_school_risk_02" "school" "4" "school" "school_complete" "counter.gamble_sessions>=3" 211 "game" 2 "Protagonist" "나" "narration" "" "수업이 끝난 뒤에도 선생님의 말이 계속 남았다. 지금 말하면 숨긴 일까지 전부 설명해야 한다."))
$rows.Add((New-ScenarioRow "v5_d4_school_risk" "v5_d4_school_risk_03" "school" "4" "school" "school_complete" "counter.gamble_sessions>=3" 211 "game" 3 "Teacher" "담임 선생님" "dialogue" "" "요즘 계속 피곤해 보이는데 무슨 일 있니? 천천히 말해도 괜찮아." "d13_tell_teacher" "선생님께 사실대로 말한다" "선생님, 사실 도박하다 돈을 잃었어요. 혼자서는 멈추기 어려워요." "flag.help_requested:set=true|relation.teacher:add=3" "v5_d4_help_response" "d13_hide_again" "아무 일도 아니라고 한다" "아니에요. 그냥 알바 때문에 피곤해서 그래요." "flag.help_requested:set=false|relation.teacher:add=-2" "v5_d4_hide_result" -Purpose "최종 엔딩을 가르는 도움 요청을 하루 앞에 배치한다."))
$rows.Add((New-ScenarioRow "v5_d4_help_response" "v5_d4_help_response_01" "school" "4" "after_school" "v5_d4_help_response" "" 205 "game" 1 "Teacher" "담임 선생님" "dialogue" "" "말해줘서 잘했어. 혼자 갚으려고 다시 도박하지 말고 부모님과 상담 선생님께 같이 이야기하자."))
$rows.Add((New-ScenarioRow "v5_d4_help_response" "v5_d4_help_response_02" "school" "4" "after_school" "v5_d4_help_response" "" 205 "game" 2 "Protagonist" "나" "dialogue" "" "네. 무섭지만 더 숨기지는 않을게요. 집에 가서 발표자료도 마무리할게요." -Effects "unlock.counseling:set=true|tutorial:set=study"))
$rows.Add((New-ScenarioRow "v5_d4_hide_result" "v5_d4_hide_result_01" "school" "4" "after_school" "v5_d4_hide_result" "" 205 "game" 1 "Protagonist" "나" "narration" "" "괜찮다고 말하고 교무실을 나왔다. 안도감보다 다시 혼자가 됐다는 생각이 더 크게 남았다. 일단 집에 가서 내일 발표자료부터 마무리하자." -Effects "tutorial:set=study"))
$rows.Add((New-ScenarioRow "v5_d4_study_done_stable" "v5_d4_study_done_stable_01" "study" "4" "evening" "homework_complete" "counter.gamble_sessions<3" 180 "game" 1 "Seoyeon" "서연" "message" "seoyeon_default" "자료 확인했어. 사례랑 도움받는 방법까지 잘 정리됐네. 내일 발표 때 같이 보자." "v5_d4_study_reply" "내일 보자고 답한다." "응. 내일 발표 전에 한 번 더 맞춰보자." "relation.seoyeon:add=2|schedule.project:set=complete" ""))
$rows.Add((New-ScenarioRow "v5_d4_study_done_risk" "v5_d4_study_done_risk_01" "study" "4" "evening" "homework_complete" "counter.gamble_sessions>=3" 181 "game" 1 "Seoyeon" "서연" "message" "seoyeon_worried" "늦을까 봐 걱정했는데 자료는 왔네. 내일 발표할 수 있겠어?" "v5_d4_study_risk_reply" "발표는 하겠다고 답한다." "응. 내일은 피하지 않고 학교 갈게." "relation.seoyeon:add=1|schedule.project:set=complete" ""))
$rows.Add((New-ScenarioRow "v5_d4_evening" "v5_d4_evening_01" "main" "4" "evening" "evening_fill" "schedule.homework=complete" 90 "day" 1 "Protagonist" "나" "overlay" "" "발표 준비는 끝났다. 오늘 선택한 말의 결과는 내일 마주해야 한다." -Effects "clock:set=21:00"))

# Day 5: Tuesday, final presentation and explicit result cards.
$rows.Add((New-ScenarioRow "v5_d5_start_recovery" "v5_d5_start_recovery_01" "main" "5" "7:00" "day_start" "flag.help_requested=true;flag.late_wake_today!=true" 230 "game" 1 "Protagonist" "나" "narration" "" "화요일 아침. 어제 선생님께 말한 뒤 부모님과 상담 일정을 잡았다. 문제는 남아 있지만 더 숨기지는 않기로 했다." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d5_start_no_help" "v5_d5_start_no_help_01" "main" "5" "7:00" "day_start" "flag.help_requested!=true;counter.gamble_sessions>=3;flag.late_wake_today!=true" 229 "game" 1 "Protagonist" "나" "narration" "" "화요일 아침. 발표 날인데도 잃은 돈을 되찾을 생각부터 떠올랐다. 어제도 결국 아무에게도 말하지 못했다." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d5_start_prevented" "v5_d5_start_prevented_01" "main" "5" "7:00" "day_start" "counter.gamble_sessions<3;flag.late_wake_today!=true" 228 "game" 1 "Protagonist" "나" "narration" "" "화요일 아침. 오늘은 조별 발표가 있는 날이다. 유혹은 있었지만 해야 할 일을 먼저 끝낼 수 있었다." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d5_school_recovery" "v5_d5_school_recovery_01" "school" "5" "school" "school_complete" "flag.help_requested=true" 220 "game" 1 "Seoyeon" "서연" "dialogue" "seoyeon_default" "발표 잘 끝났다. 요즘 힘들어 보였는데도 네 역할은 마무리했네."))
$rows.Add((New-ScenarioRow "v5_d5_school_recovery" "v5_d5_school_recovery_02" "school" "5" "school" "school_complete" "flag.help_requested=true" 220 "game" 2 "Teacher" "담임 선생님" "dialogue" "" "어제 먼저 말해 준 것도 잘한 선택이야. 이제 부모님과 돈 문제, 밀린 일정을 하나씩 정리하자."))
$rows.Add((New-ScenarioRow "v5_d5_school_recovery" "v5_d5_school_recovery_03" "school" "5" "school" "school_complete" "flag.help_requested=true" 220 "game" 3 "Protagonist" "나" "dialogue" "" "네. 잃은 돈을 되찾으려고 다시 도박하지 않고, 지금 상황부터 계획대로 정리할게요." -Next "v5_recovery_goal_router"))
$rows.Add((New-ScenarioRow "v5_recovery_goal_router" "v5_recovery_goal_router_01" "ending" "5" "ending" "v5_recovery_goal_router" "" 219 "game" 1 "System" "" "router" "" "" -Effects "route:v5_recovery_debt if debt>0 else v5_recovery_no_debt"))
$rows.Add((New-ScenarioRow "v5_recovery_debt" "v5_recovery_debt_01" "ending" "5" "ending" "v5_recovery_debt" "" 218 "game" 1 "Protagonist" "나" "dialogue" "" "수리비보다 갚아야 할 돈을 먼저 정리해야 한다. 그래도 이제는 혼자 숨기지 않는다." -Next "ending_recovery"))
$rows.Add((New-ScenarioRow "v5_recovery_no_debt" "v5_recovery_no_debt_01" "ending" "5" "ending" "v5_recovery_no_debt" "" 218 "game" 1 "Protagonist" "나" "dialogue" "" "잃은 돈은 남았지만 더 큰 빚을 만들기 전에 멈췄다. 이제 밀린 일정을 다시 세우자." -Next "ending_recovery"))
$rows.Add((New-ScenarioRow "ending_recovery" "ending_recovery_01" "ending" "5" "ending" "ending_recovery" "" 300 "game" 1 "Narrator" "" "ending" "" "문제는 한 번에 사라지지 않았지만, 도움을 요청한 순간부터 회복은 시작됐다." -Effects "ending:set=recovery" -Purpose "도움 요청을 분명한 회복 결과로 표시한다."))
$rows.Add((New-ScenarioRow "v5_d5_school_no_help" "v5_d5_school_no_help_01" "school" "5" "school" "school_complete" "flag.help_requested!=true;counter.gamble_sessions>=3" 219 "game" 1 "Teacher" "담임 선생님" "dialogue" "" "발표는 끝났지만 네 상태는 그냥 넘길 수 없겠다. 보호자와 같이 이야기하자."))
$rows.Add((New-ScenarioRow "v5_d5_school_no_help" "v5_d5_school_no_help_02" "school" "5" "school" "school_complete" "flag.help_requested!=true;counter.gamble_sessions>=3" 219 "game" 2 "Protagonist" "나" "narration" "" "끝까지 숨기려 했지만 반복한 도박과 끊이지 않는 메시지까지 혼자 감출 수는 없었다."))
$rows.Add((New-ScenarioRow "v5_d5_school_no_help" "v5_d5_school_no_help_03" "school" "5" "school" "school_complete" "flag.help_requested!=true;counter.gamble_sessions>=3" 219 "game" 3 "Narrator" "" "narration" "" "결국 보호자와 학교에 상황이 알려졌고, 불법 도박 문제는 경찰 상담으로까지 이어졌다." -Next "ending_no_help"))
$rows.Add((New-ScenarioRow "ending_no_help" "ending_no_help_01" "ending" "5" "ending" "ending_no_help" "" 300 "game" 1 "Narrator" "" "ending" "" "손실을 혼자 되찾으려는 선택은 빚과 놓친 일정을 더 크게 만들었다. 숨긴 문제는 저절로 사라지지 않았다." -Effects "ending:set=no_help" -Purpose "지속한 선택의 결과와 도움 필요성을 명확히 표시한다."))
$rows.Add((New-ScenarioRow "v5_d5_school_prevented" "v5_d5_school_prevented_01" "school" "5" "school" "school_complete" "counter.gamble_sessions<3" 218 "game" 1 "Teacher" "담임 선생님" "dialogue" "" "발표 좋았어. 위험 신호와 도움받는 방법을 구체적으로 잘 설명했구나."))
$rows.Add((New-ScenarioRow "v5_d5_school_prevented" "v5_d5_school_prevented_02" "school" "5" "school" "school_complete" "counter.gamble_sessions<3" 218 "game" 2 "Seoyeon" "서연" "dialogue" "seoyeon_default" "자료까지 끝냈잖아. 오늘 같이 발표할 수 있어서 다행이었어."))
$rows.Add((New-ScenarioRow "v5_d5_school_prevented" "v5_d5_school_prevented_03" "school" "5" "school" "school_complete" "counter.gamble_sessions<3" 218 "game" 3 "Protagonist" "나" "dialogue" "" "응. 빨리 돈을 만드는 것보다 해야 할 일을 먼저 확인하는 게 맞았어." -Next "v5_prevented_goal_router"))
$rows.Add((New-ScenarioRow "v5_prevented_goal_router" "v5_prevented_goal_router_01" "ending" "5" "ending" "v5_prevented_goal_router" "" 217 "game" 1 "System" "" "router" "" "" -Effects "route:v5_prevented_goal_full if counter.job_attendance>=2;counter.gamble_sessions=0 else v5_prevented_goal_mixed_router"))
$rows.Add((New-ScenarioRow "v5_prevented_goal_mixed_router" "v5_prevented_goal_mixed_router_01" "ending" "5" "ending" "v5_prevented_goal_mixed_router" "" 216 "game" 1 "System" "" "router" "" "" -Effects "route:v5_prevented_goal_mixed if cash>=250000 else v5_prevented_goal_short"))
$rows.Add((New-ScenarioRow "v5_prevented_goal_full" "v5_prevented_goal_full_01" "ending" "5" "ending" "v5_prevented_goal_full" "" 215 "game" 1 "Protagonist" "나" "dialogue" "" "주말 근무를 이틀 다 나간 덕분에 수리비 25만 원을 채웠다. 오래 걸렸지만 계획대로 모은 돈이었다." -Next "ending_prevented"))
$rows.Add((New-ScenarioRow "v5_prevented_goal_mixed" "v5_prevented_goal_mixed_01" "ending" "5" "ending" "v5_prevented_goal_mixed" "" 215 "game" 1 "Protagonist" "나" "dialogue" "" "목표 금액은 채웠지만 도박에서 생긴 돈도 섞여 있다. 운 좋게 멈춘 것이지 안전한 방법이었던 건 아니다." -Next "ending_prevented"))
$rows.Add((New-ScenarioRow "v5_prevented_goal_short" "v5_prevented_goal_short_01" "ending" "5" "ending" "v5_prevented_goal_short" "" 215 "game" 1 "Protagonist" "나" "dialogue" "" "수리비를 전부 채우진 못했다. 그래도 남은 금액과 일정을 다시 계산하니 언제 모을 수 있을지는 보였다." -Next "ending_prevented"))
$rows.Add((New-ScenarioRow "ending_prevented" "ending_prevented_01" "ending" "5" "ending" "ending_prevented" "" 300 "game" 1 "Narrator" "" "ending" "" "유혹보다 일상을 먼저 선택했습니다. 스스로 멈춘 결정이 가장 중요한 예방이 되었습니다." -Effects "ending:set=prevented" -Purpose "성공 여부를 즉시 이해할 수 있는 예방 성공 카드다."))
$rows.Add((New-ScenarioRow "v5_d5_missed_recovery" "v5_d5_missed_recovery_01" "ending" "5" "night" "school_missed" "flag.help_requested=true" 220 "day" 1 "Teacher" "담임 선생님" "message" "" "오늘 학교에 못 왔구나. 발표보다 네 상태가 먼저야. 부모님과 약속한 상담은 그대로 진행하자."))
$rows.Add((New-ScenarioRow "v5_d5_missed_recovery" "v5_d5_missed_recovery_02" "ending" "5" "night" "school_missed" "flag.help_requested=true" 220 "day" 2 "Protagonist" "담임 선생님" "message" "" "네. 오늘 상담은 피하지 않고 부모님과 같이 가겠습니다." -Next "v5_recovery_goal_router"))
$rows.Add((New-ScenarioRow "v5_d5_missed_no_help" "v5_d5_missed_no_help_01" "ending" "5" "night" "school_missed" "flag.help_requested!=true;counter.gamble_sessions>=3" 219 "day" 1 "Teacher" "담임 선생님" "message" "" "오늘도 학교에 오지 않았구나. 보호자에게 연락해서 지금 상황부터 같이 확인하겠다."))
$rows.Add((New-ScenarioRow "v5_d5_missed_no_help" "v5_d5_missed_no_help_02" "ending" "5" "night" "school_missed" "flag.help_requested!=true;counter.gamble_sessions>=3" 219 "day" 2 "Protagonist" "담임 선생님" "message" "" "네.... 집에서 기다리겠습니다." -Next "ending_no_help"))
$rows.Add((New-ScenarioRow "v5_d5_missed_prevented" "v5_d5_missed_prevented_01" "ending" "5" "night" "school_missed" "counter.gamble_sessions<3" 218 "day" 1 "Seoyeon" "서연" "message" "seoyeon_worried" "오늘 발표에 못 왔네. 무슨 일 있는 건 아니지? 다음엔 일정이 꼬이기 전에 먼저 알려 줘."))
$rows.Add((New-ScenarioRow "v5_d5_missed_prevented" "v5_d5_missed_prevented_02" "ending" "5" "night" "school_missed" "counter.gamble_sessions<3" 218 "day" 2 "Protagonist" "서연" "message" "" "미안해. 다음엔 늦기 전에 먼저 연락할게. 자료 챙겨줘서 고마워." -Next "v5_prevented_goal_router"))

$rows | Select-Object $columns | Export-Csv -LiteralPath (Join-Path $resourcePath "ScenarioV5.csv") -NoTypeInformation -Encoding utf8BOM -UseQuotes Always

$flowKeep = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($row in $rows) { [void]$flowKeep.Add($row.scene_id) }
$oldFlow = Import-Csv -LiteralPath (Join-Path $resourcePath "ScenarioV3Flow.csv")
$flowRows = [System.Collections.Generic.List[object]]::new()
foreach ($row in $oldFlow) {
    if ($flowKeep.Contains($row.scene_id)) { $flowRows.Add($row) }
}
$customReturnToTablet = @(
    "v5_d2_start", "v5_d2_job", "v5_d2_evening_done", "v5_d2_evening_missed",
    "v5_d3_start", "v5_d3_job_good", "v5_d3_job_return", "v5_d3_evening_done", "v5_d3_evening_missed",
    "v5_d4_start_stable", "v5_d4_start_risk", "v5_d4_help_response", "v5_d4_hide_result",
    "v5_d4_study_done_stable", "v5_d4_study_done_risk", "v5_d4_evening",
    "v5_d5_start_recovery", "v5_d5_start_no_help", "v5_d5_start_prevented"
)
foreach ($scene in $customReturnToTablet) {
    $flowRows.Add([pscustomobject]@{ scene_id = $scene; extra_trigger = ""; return_to_tablet = "true" })
}
$flowRows | Sort-Object scene_id -Unique | Export-Csv -LiteralPath (Join-Path $resourcePath "ScenarioV5Flow.csv") -NoTypeInformation -Encoding utf8BOM -UseQuotes Always

@(
    [pscustomobject]@{ choice_id = "g3_stop"; label = "첫 손실을 마주한 순간" },
    [pscustomobject]@{ choice_id = "g3_chase"; label = "첫 손실을 마주한 순간" },
    [pscustomobject]@{ choice_id = "d13_tell_teacher"; label = "선생님께 말하기 전" },
    [pscustomobject]@{ choice_id = "d13_hide_again"; label = "선생님께 말하기 전" }
) | Export-Csv -LiteralPath (Join-Path $resourcePath "ScenarioV5Checkpoints.csv") -NoTypeInformation -Encoding utf8BOM -UseQuotes Always

Write-Host "ScenarioV5 resources generated: $($rows.Count) lines"
