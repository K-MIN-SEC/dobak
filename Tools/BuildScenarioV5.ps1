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
            "d1_intro_01" { $row.enter_effects = "clock:set=07:00|cash:set=50000|debt:set=0|flag.gambling_started:set=false" }
            "d1_intro_goal_01" {
                $row.text = "며칠 전 책상에서 떨어뜨린 노트북이 아예 켜지지 않았다. 과제랑 발표에도 써야 하는데, 수리비로 15만 원이 든다고 했다."
                $row.enter_effects = "money_goal:set=150000"
            }
            "d1_intro_goal_02" { $row.text = "내가 떨어뜨린 거라 부모님께 또 부탁하기도 애매했다. 통장에 모아 둔 돈은 5만 원." }
            "d1_intro_goal_03" { $row.text = "이번 주말 알바를 이틀 다 나가면 10만 원을 더 모을 수 있다. 그러면 수리비 15만 원을 채울 수 있다. 괜히 다른 방법 찾지 말고 일정부터 지키자." }
            "d1_school_01" { $row.text = "다음 주 화요일에 조별 발표할 거야. 온라인 도박 광고가 확률과 보상을 어떻게 포장하는지, 위험할 때 어디서 도움받을 수 있는지 조사해 보자." }
            "d1_school_02" { $row.text = "다음 주에 바로 조별 발표라니. 누구랑 같은 조지?" }
            "d1_school_05" { $row.text = "월요일까지 도박 피해 사례랑 도움받을 곳을 정리해 줄래? 나는 도박문제예방치유원에서 광고의 유혹 장치를 찾아볼게." }
            "d1_school_09" { $row.text = "응. 내가 찾은 자료는 월요일 학교에서 보여줄게. 주말 잘 보내." }
            "d1_school_10" { $row.text = "그래. 월요일에 보자." }
            "d1_school_missed_message_01" {
                $row.text = "오늘 학교 안 왔더라. 우리 둘이 같은 조 됐어. 다음 주 화요일에 온라인 광고랑 확률 표현으로 발표한대."
                $row.enter_effects = "flag.project_introduced:set=true"
            }
            "d1_school_missed_message_02" { $row.text = "월요일까지 도박 피해 사례랑 도움받을 곳을 정리해 줄래? 나는 도박문제예방치유원에서 광고의 유혹 장치를 찾아볼게." }
            "d1_minjae_invite_04" { $row.text = "수리비까지 남은 돈은 10만 원이다. 주말 이틀을 다 일하면 채울 수 있지만, 가입 보너스로 시작하면 더 빨라질지도 모른다.... 아니, 이런 생각부터 이상한 건가." }
            "d1_minjae_invite_02" { $row.text = "신규 가입하면 무료 포인트 줌. 오늘 자정 전엔 추천 보너스도 두 배래." }
            "d1_evening_02" { $row.text = "오늘은 여기까지 하자. 내일 알바도 있으니까 씻고 잘 준비나 해야겠다." }
            "mom_loan_message_03" { $row.text = "일단 보냈어. 나중에 어디에 썼는지 같이 보자." }
            "mom_loan_message_04" { $row.text = "엄마 고마워. 나중에 어디에 썼는지 제대로 말할게." }
            "mom_loan_response_02" { $row.text = "일단 보냈어. 나중에 어디에 썼는지 같이 보자." }
            "mom_loan_response_03" { $row.text = "엄마 고마워. 나중에 어디에 썼는지 제대로 말할게." }
            "collapse_check_stable_01" {
                $row.day = "5"
                $row.condition = "schedule_failures>=3|counter.school_absences>=3|counter.job_failures>=2;counter.gamble_sessions<3;debt=0"
            }
            "collapse_check_gamble_01" {
                $row.day = "5"
                $row.condition = "schedule_failures>=3|counter.school_absences>=3|counter.job_failures>=2;counter.gamble_sessions>=3;debt=0"
            }
            "collapse_check_debt_01" {
                $row.day = "5"
                $row.condition = "schedule_failures>=3|counter.school_absences>=3|counter.job_failures>=2;counter.gamble_sessions>=3;debt>0"
            }
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
$rows.Add((New-ScenarioRow "v5_d2_start" "v5_d2_start_02" "main" "2" "7:00" "day_start" "" 220 "day" 2 "Protagonist" "나" "dialogue" "" "오늘 근무를 마치면 일당 5만 원을 받는다. 지금 모은 돈에 얼마나 보탤 수 있는지 확인하고 늦지 않게 출발하자." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d2_minjae" "v5_d2_minjae_01" "gambling" "2" "morning" "day_start" "" 180 "day" 1 "Minjae" "민재" "message" "minjae_default" "오늘 알바지? 하루 종일 일해서 5만 원 받느니 어제 보낸 앱이 훨씬 빠르다니까." "v5_d2_reply_job" "알바부터 갈 거야." "오늘은 알바부터 갈 거야. 끝나고 내가 정할게." "counter.refusals:add=1" "" "v5_d2_reply_later" "끝나고 확인해 볼게." "알바 끝나고 확인해 볼게. 지금은 늦으면 안 돼." "gamble:offer" "" -Purpose "도박 여부는 메시지 선택이 아니라 일정 완료 뒤 앱에서 결정한다."))
$rows.Add((New-ScenarioRow "v5_d2_job" "v5_d2_job_01" "job" "2" "job" "job_complete" "" 190 "game" 1 "CafeManager" "점장님" "dialogue" "manager_default" "첫날이니까 주문보다 정리부터 익혀. 모르는 건 바로 물어보고."))
$rows.Add((New-ScenarioRow "v5_d2_job" "v5_d2_job_02" "job" "2" "job" "job_complete" "" 190 "game" 2 "Protagonist" "나" "narration" "" "정신없이 움직이다 보니 어느새 마감 시간이었다."))
$rows.Add((New-ScenarioRow "v5_d2_job" "v5_d2_job_03" "job" "2" "job" "job_complete" "" 190 "game" 3 "CafeManager" "점장님" "dialogue" "manager_default" "오늘 일당 5만 원은 넣어뒀어. 내일도 같은 시간에 보자." -Effects "counter.job_attendance:add=1|relation.manager:add=1" -Purpose "첫 근무와 정상 수입을 보여 준다."))
$rows.Add((New-ScenarioRow "v5_d2_job" "v5_d2_job_04" "job" "2" "job" "job_complete" "" 190 "game" 4 "Protagonist" "나" "dialogue" "" "네, 감사합니다. 내일도 시간 맞춰 올게요." -Purpose "점장에게 인사한 뒤 귀가한다."))
$rows.Add((New-ScenarioRow "v5_d2_job_missed" "v5_d2_job_missed_01" "job" "2" "afternoon" "job_missed" "" 190 "day" 1 "CafeManager" "점장님" "message" "manager_worried" "오늘 첫 출근인데 연락도 없이 안 왔네. 무슨 일 있니?" "v5_d2_missed_apology" "죄송하다고 답한다." "죄송해요. 시간을 놓쳤어요. 내일은 꼭 먼저 연락드릴게요." "relation.manager:add=-2" "" -Purpose "첫 결근을 즉시 관계 결과로 돌려준다."))
$rows.Add((New-ScenarioRow "v5_d2_minjae_after_miss" "v5_d2_minjae_after_miss_01" "gambling" "2" "afternoon" "job_missed" "schedule.job=missed" 185 "day" 1 "Minjae" "민재" "message" "minjae_default" "그 뒤로 답이 없네. 설마 알바 안 갔어?" -Purpose "아침 권유 뒤 결근 사실을 알아챈 민재가 다시 접근한다."))
$rows.Add((New-ScenarioRow "v5_d2_minjae_after_miss" "v5_d2_minjae_after_miss_02" "gambling" "2" "afternoon" "job_missed" "schedule.job=missed" 185 "day" 2 "Protagonist" "민재" "message" "" "응. 시간을 놓쳐서 오늘은 못 갔어."))
$rows.Add((New-ScenarioRow "v5_d2_minjae_after_miss" "v5_d2_minjae_after_miss_03" "gambling" "2" "afternoon" "job_missed" "schedule.job=missed" 185 "day" 3 "Minjae" "민재" "message" "minjae_default" "그럼 한 판이라도 해 봐. 못 받은 알바비부터 메워야지."))
$rows.Add((New-ScenarioRow "v5_d2_minjae_after_miss" "v5_d2_minjae_after_miss_04" "gambling" "2" "afternoon" "job_missed" "schedule.job=missed" 185 "day" 4 "Protagonist" "민재" "message" "" "일단 생각해 볼게." -Effects "gamble:offer" -Purpose "민재의 유혹에 즉시 동의하지 않고, 일정 완료 뒤 플레이어가 판단하게 한다."))
$rows.Add((New-ScenarioRow "v5_d2_missed_daytime" "v5_d2_missed_daytime_01" "main" "2" "daytime" "job_missed" "schedule.job=missed;schedule.homework=pending" 175 "day" 1 "Protagonist" "나" "narration" "" "점장님께 사과하고 늦은 아침을 먹었다. 알바 대신 밀린 집안일과 조별과제 자료를 정리하다 보니 어느새 16시가 됐다." -Effects "clock:advance_to=16:00" -Purpose "오전 결근 뒤 낮 배경 장면으로 남은 시간을 자연스럽게 연결한다."))
$rows.Add((New-ScenarioRow "v5_d2_study_cue_done" "v5_d2_study_cue_done_01" "study" "2" "16:00" "post_job_home" "schedule.job=complete;schedule.homework=pending" 196 "day" 1 "Protagonist" "나" "overlay" "" "첫 근무를 마치고 집에 오니 16시다. 오늘 번 5만 원이 통장에 들어왔지만, 아직 서연과 약속한 조별과제가 남아 있다."))
$rows.Add((New-ScenarioRow "v5_d2_study_cue_done" "v5_d2_study_cue_done_02" "study" "2" "16:00" "post_job_home" "schedule.job=complete;schedule.homework=pending" 196 "day" 2 "Seoyeon" "서연" "message" "seoyeon_default" "알바 끝났어? 어제 맡은 상담 번호랑 어떤 도움을 받을 수 있는지 오늘 정리해 줄 수 있어?"))
$rows.Add((New-ScenarioRow "v5_d2_study_cue_done" "v5_d2_study_cue_done_03" "study" "2" "16:00" "post_job_home" "schedule.job=complete;schedule.homework=pending" 196 "day" 3 "Protagonist" "서연" "message" "" "응, 지금 집에 왔어. 번호만 쓰지 않고 상담 내용이랑 출처까지 확인해서 보낼게."))
$rows.Add((New-ScenarioRow "v5_d2_study_cue_done" "v5_d2_study_cue_done_04" "study" "2" "16:00" "post_job_home" "schedule.job=complete;schedule.homework=pending" 196 "day" 4 "Protagonist" "나" "overlay" "" "서연에게 답장도 했으니 공부 앱에서 자료 조사를 시작하자." -Effects "tutorial:set=study" -Purpose "알바 귀가 뒤 서연의 메시지를 확인하고 답한 다음 공부 앱으로 연결한다."))
$rows.Add((New-ScenarioRow "v5_d2_study_cue_missed" "v5_d2_study_cue_missed_01" "study" "2" "afternoon" "job_missed" "schedule.job=missed;schedule.homework=pending" 170 "day" 1 "Protagonist" "나" "overlay" "" "오늘 알바는 놓쳤다. 수리비 계획은 틀어졌지만 서연과 약속한 조별과제까지 미룰 수는 없다."))
$rows.Add((New-ScenarioRow "v5_d2_study_cue_missed" "v5_d2_study_cue_missed_02" "study" "2" "afternoon" "job_missed" "schedule.job=missed;schedule.homework=pending" 170 "day" 2 "Seoyeon" "서연" "message" "seoyeon_default" "어제 맡은 상담 번호 자료, 오늘 확인할 수 있지? 번호만 말고 어떤 도움을 받을 수 있는지도 부탁해."))
$rows.Add((New-ScenarioRow "v5_d2_study_cue_missed" "v5_d2_study_cue_missed_03" "study" "2" "afternoon" "job_missed" "schedule.job=missed;schedule.homework=pending" 170 "day" 3 "Protagonist" "서연" "message" "" "응. 늦지 않게 상담 내용이랑 출처까지 확인해서 보낼게."))
$rows.Add((New-ScenarioRow "v5_d2_study_cue_missed" "v5_d2_study_cue_missed_04" "study" "2" "afternoon" "job_missed" "schedule.job=missed;schedule.homework=pending" 170 "day" 4 "Protagonist" "나" "overlay" "" "적어도 약속한 자료는 끝내자. 공부 앱에서 상담 정보를 조사하자." -Effects "tutorial:set=study"))
$rows.Add((New-ScenarioRow "v5_d2_study_done" "v5_d2_study_done_01" "study" "2" "evening" "homework_complete" "" 205 "game" 1 "Protagonist" "서연" "message" "" "서연아. 도박 문제 상담은 국번 없이 1336이래. 전화로 상담받을 수 있고, 가족이나 주변 사람도 도움을 요청할 수 있대."))
$rows.Add((New-ScenarioRow "v5_d2_study_done" "v5_d2_study_done_02" "study" "2" "evening" "homework_complete" "" 205 "game" 2 "Seoyeon" "서연" "message" "seoyeon_default" "1336 맞아. 출처까지 같이 적어줘서 첫 장 정리하기 편하겠다."))
$rows.Add((New-ScenarioRow "v5_d2_study_done" "v5_d2_study_done_03" "study" "2" "evening" "homework_complete" "" 205 "game" 3 "Seoyeon" "서연" "message" "seoyeon_default" "내일은 내가 찾은 사례를 보내줄게. 처음에 왜 빠져들었고 어떤 순간부터 문제가 커졌는지 같이 보자."))
$rows.Add((New-ScenarioRow "v5_d2_study_done" "v5_d2_study_done_04" "study" "2" "evening" "homework_complete" "" 205 "game" 4 "Protagonist" "서연" "message" "" "응. 내일 알바 끝나고 사례 확인해서 내 생각도 보내줄게." -Effects "project.progress:add=1|relation.seoyeon:add=1" -Purpose "공부 결과를 주인공이 먼저 보내고 다음 과제 약속에도 답한다."))
$rows.Add((New-ScenarioRow "v5_d2_night_done" "v5_d2_night_done_01" "sleep" "2" "21:00" "evening_fill" "schedule.job=complete;schedule.homework=complete" 90 "day" 1 "Protagonist" "나" "overlay" "" "서연에게 자료를 보내고 답장까지 마쳤다. 저녁을 먹고 내일 근무 준비를 하다 보니 21시가 됐다." -Effects "clock:set=21:00" -Purpose "서연과의 대화가 끝난 뒤에만 밤 장면으로 전환한다."))
$rows.Add((New-ScenarioRow "v5_d2_night_missed" "v5_d2_night_missed_01" "sleep" "2" "21:00" "evening_fill" "schedule.job=missed;schedule.homework=complete" 89 "day" 1 "Protagonist" "나" "overlay" "" "서연에게 자료를 보내고 답장까지 마쳤다. 오늘 몫 5만 원은 비었지만 내일 근무 준비를 하다 보니 21시가 됐다." -Effects "clock:set=21:00" -Purpose "결근 경로도 공부와 메시지를 마친 뒤 밤으로 전환한다."))

# Day 3: Sunday, second job shift and escalating temptation.
$rows.Add((New-ScenarioRow "v5_d3_start" "v5_d3_start_01" "main" "3" "7:00" "day_start" "flag.late_wake_today!=true" 220 "day" 1 "Protagonist" "나" "narration" "" "일요일 아침. 오늘 카페 근무까지 마치면 이번 주말 일정은 끝난다."))
$rows.Add((New-ScenarioRow "v5_d3_start" "v5_d3_start_02" "main" "3" "7:00" "day_start" "" 220 "day" 2 "Protagonist" "나" "dialogue" "" "오늘도 출근 시간이 정해져 있다. 남은 일은 근무를 마치고 생각하자. 먼저 카페에 가자." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d3_minjae_none" "v5_d3_minjae_none_01" "gambling" "3" "morning" "day_start" "counter.gamble_sessions=0" 182 "day" 1 "Minjae" "민재" "message" "minjae_default" "아직도 안 해봤어? 보너스 없어지기 전에 한 번만 눌러 봐." "v5_d3_none_reply" "오늘도 알바부터 간다." "오늘도 알바부터 갈 거야. 계속 재촉하지 마." "counter.refusals:add=1" ""))
$rows.Add((New-ScenarioRow "v5_d3_minjae_profit" "v5_d3_minjae_profit_01" "gambling" "3" "morning" "day_start" "counter.gamble_sessions>=1;counter.gamble_sessions<3" 183 "day" 1 "Minjae" "민재" "message" "minjae_default" "전에 바로 돈 들어오는 거 봤잖아. 오늘도 한 번만 하면 수리비 금방 채우겠다." "v5_d3_profit_stop" "번 돈으로 끝낸다." "그때 번 건 운이 좋았던 거야. 오늘은 알바부터 갈게." "counter.refusals:add=1" "" "v5_d3_profit_later" "알바 뒤에 생각한다." "지금은 알바 가야 해. 끝나고 내가 정할게." "gamble:offer" ""))
$rows.Add((New-ScenarioRow "v5_d3_minjae_loss" "v5_d3_minjae_loss_01" "gambling" "3" "morning" "day_start" "counter.gamble_sessions>=3" 184 "day" 1 "Minjae" "민재" "message" "minjae_angry" "지금 멈추면 잃은 돈 그대로잖아. 오늘 흐름 좋다니까 알바 끝나고라도 복구해." "v5_d3_loss_stop" "더 잃기 전에 멈춘다." "잃은 돈 때문에 또 들어가진 않을 거야. 오늘 일정부터 지킬게." "counter.refusals:add=1" "" "v5_d3_loss_later" "알바 뒤에 다시 본다." "일단 알바부터 갈게. 끝나고 다시 생각해 볼게." "gamble:offer" ""))
$rows.Add((New-ScenarioRow "v5_d3_job_good" "v5_d3_job_good_01" "job" "3" "job" "job_complete" "counter.job_attendance>=1" 192 "game" 1 "CafeManager" "점장님" "dialogue" "manager_default" "주말 이틀 다 시간 맞춰 왔네. 오늘 일당까지 넣어뒀어. 수고했다." -Effects "counter.job_attendance:add=1|relation.manager:add=2"))
$rows.Add((New-ScenarioRow "v5_d3_job_good" "v5_d3_job_good_02" "job" "3" "job" "job_complete" "counter.job_attendance>=1" 192 "game" 2 "Protagonist" "나" "dialogue" "" "감사합니다. 오늘도 수고하셨어요." -Purpose "점장에게 인사한 뒤 귀가한다."))
$rows.Add((New-ScenarioRow "v5_d3_job_return" "v5_d3_job_return_01" "job" "3" "job" "job_complete" "counter.job_attendance=0" 191 "game" 1 "CafeManager" "점장님" "dialogue" "manager_worried" "어제는 걱정했어. 오늘 나온 건 다행이지만 다음에는 늦기 전에 꼭 연락해." -Effects "counter.job_attendance:add=1|relation.manager:add=-1"))
$rows.Add((New-ScenarioRow "v5_d3_job_return" "v5_d3_job_return_02" "job" "3" "job" "job_complete" "counter.job_attendance=0" 191 "game" 2 "Protagonist" "나" "dialogue" "" "죄송합니다. 다음에는 늦기 전에 꼭 연락드릴게요." -Purpose "점장에게 인사한 뒤 귀가한다."))
$rows.Add((New-ScenarioRow "v5_d3_case_cue_done" "v5_d3_case_cue_done_00" "study" "3" "16:00" "post_job_home" "schedule.job=complete;schedule.homework=pending" 198 "day" 0 "Protagonist" "나" "overlay" "" "두 번째 근무를 마치고 집에 오니 16시다. 주말 알바는 끝났지만 월요일 발표 전에 정리할 사례가 남아 있다." -Purpose "귀가 직후 저녁 장면을 먼저 보여 준다."))
$rows.Add((New-ScenarioRow "v5_d3_job_missed_first" "v5_d3_job_missed_first_01" "job" "3" "afternoon" "job_missed" "counter.job_failures=0" 192 "day" 1 "CafeManager" "점장님" "message" "manager_worried" "오늘 출근하지 않았네. 계속 근무할 생각이 있는지는 알려 줘." "v5_d3_missed_apology" "사과하고 다시 기회를 부탁한다." "죄송해요. 다음 근무 전에는 꼭 먼저 연락드릴게요." "relation.manager:add=-2" ""))
$rows.Add((New-ScenarioRow "v5_d3_job_missed_fired" "v5_d3_job_missed_fired_01" "job" "3" "afternoon" "job_missed" "counter.job_failures>=1" 193 "day" 1 "CafeManager" "점장님" "message" "manager_angry" "두 번 연속 연락 없이 빠졌어. 다음 근무는 당분간 잡기 어렵겠다." "v5_d3_fired_reply" "죄송하다고 답한다." "죄송합니다. 제가 약속을 지키지 못했어요." "relation.manager:add=-3|flag.job_fired:set=true" "" -Purpose "연속 결근을 명확한 해고 결과로 보여 준다."))
$rows.Add((New-ScenarioRow "v5_d3_minjae_after_miss" "v5_d3_minjae_after_miss_01" "gambling" "3" "afternoon" "job_missed" "schedule.job=missed" 185 "day" 1 "Minjae" "민재" "message" "minjae_default" "아까부터 답이 없네. 오늘 알바 안 갔어?" -Purpose "다른 주말 결근에도 민재가 놓친 수입을 도박 유혹으로 연결한다."))
$rows.Add((New-ScenarioRow "v5_d3_minjae_after_miss" "v5_d3_minjae_after_miss_02" "gambling" "3" "afternoon" "job_missed" "schedule.job=missed" 185 "day" 2 "Protagonist" "민재" "message" "" "응. 오늘 근무를 놓쳤어."))
$rows.Add((New-ScenarioRow "v5_d3_minjae_after_miss" "v5_d3_minjae_after_miss_03" "gambling" "3" "afternoon" "job_missed" "schedule.job=missed" 185 "day" 3 "Minjae" "민재" "message" "minjae_default" "그럼 한 판이라도 해 봐. 못 받은 알바비는 채워야지."))
$rows.Add((New-ScenarioRow "v5_d3_minjae_after_miss" "v5_d3_minjae_after_miss_04" "gambling" "3" "afternoon" "job_missed" "schedule.job=missed" 185 "day" 4 "Protagonist" "민재" "message" "" "일단 생각해 볼게." -Effects "gamble:offer" -Purpose "도박 실행은 여전히 남은 일정 완료 뒤 플레이어가 결정한다."))
$rows.Add((New-ScenarioRow "v5_d3_missed_daytime_first" "v5_d3_missed_daytime_first_01" "main" "3" "daytime" "job_missed" "schedule.job=missed;schedule.homework=pending;counter.job_failures=0" 176 "day" 1 "Protagonist" "나" "narration" "" "점장님께 사과하고 다음 근무는 놓치지 않도록 일정을 다시 적었다. 점심을 먹고 발표 자료를 살펴보다 보니 16시가 됐다." -Effects "clock:advance_to=16:00" -Purpose "첫 결근 뒤 남은 낮 시간을 낮 배경 장면으로 연결한다."))
$rows.Add((New-ScenarioRow "v5_d3_missed_daytime_fired" "v5_d3_missed_daytime_fired_01" "main" "3" "daytime" "job_missed" "schedule.job=missed;schedule.homework=pending;counter.job_failures>=1" 176 "day" 1 "Protagonist" "나" "narration" "" "다음 근무를 잡기 어렵다는 메시지를 몇 번이나 다시 읽었다. 사라진 알바비와 수리비 계획을 다시 계산하다 보니 어느새 16시였다." -Effects "clock:advance_to=16:00" -Purpose "연속 결근 결과와 줄어든 수입을 낮 배경 장면에서 체감시킨다."))
$rows.Add((New-ScenarioRow "v5_d3_case_cue_done" "v5_d3_case_cue_done_01" "study" "3" "16:00" "post_job_home" "schedule.job=complete;schedule.homework=pending" 198 "day" 1 "Seoyeon" "서연" "message" "seoyeon_default" "알바 끝났지? 어제 말한 사례 보내둘게. 우리 또래가 무료 포인트로 시작한 이야기야."))
$rows.Add((New-ScenarioRow "v5_d3_case_cue_done" "v5_d3_case_cue_done_02" "study" "3" "16:00" "post_job_home" "schedule.job=complete;schedule.homework=pending" 198 "day" 2 "Protagonist" "서연" "message" "" "응, 지금 집이야. 처음에는 어떻게 빠져들었대?"))
$rows.Add((New-ScenarioRow "v5_d3_case_cue_done" "v5_d3_case_cue_done_03" "study" "3" "16:00" "post_job_home" "schedule.job=complete;schedule.homework=pending" 198 "day" 3 "Seoyeon" "서연" "message" "seoyeon_default" "처음엔 무료 포인트로 조금 땄대. 그러니까 다음에도 쉽게 딸 수 있을 것 같았겠지."))
$rows.Add((New-ScenarioRow "v5_d3_case_cue_done" "v5_d3_case_cue_done_04" "study" "3" "16:00" "post_job_home" "schedule.job=complete;schedule.homework=pending" 198 "day" 4 "Protagonist" "서연" "message" "" "조금 땄으면 거기서 그만두면 되는 거 아니야? 왜 계속했대?"))
$rows.Add((New-ScenarioRow "v5_d3_case_cue_done" "v5_d3_case_cue_done_05" "study" "3" "16:00" "post_job_home" "schedule.job=complete;schedule.homework=pending" 198 "day" 5 "Seoyeon" "서연" "message" "seoyeon_worried" "한 번 잃고 나서는 그것만 되찾자고 했대. 그러다 친구한테 돈을 빌리고 학교와 알바도 계속 빠졌고."))
$rows.Add((New-ScenarioRow "v5_d3_case_cue_done" "v5_d3_case_cue_done_06" "study" "3" "16:00" "post_job_home" "schedule.job=complete;schedule.homework=pending" 198 "day" 6 "Protagonist" "나" "overlay" "" "오늘 서연이가 보내 준 사례를 공부 앱에서 다시 읽어보자. 처음의 이득보다 손실을 되찾으려 한 뒤 무엇이 달라졌는지 봐야겠다." -Effects "flag.seoyeon_case_seen:set=true|tutorial:set=study" -Purpose "주인공의 질문을 통해 사례를 이해한 뒤 공부 앱으로 연결한다."))
$rows.Add((New-ScenarioRow "v5_d3_case_cue_missed" "v5_d3_case_cue_missed_01" "study" "3" "afternoon" "job_missed" "schedule.job=missed;schedule.homework=pending" 170 "day" 1 "Seoyeon" "서연" "message" "seoyeon_worried" "어제 말한 사례 보내둘게. 처음엔 조금 땄다가, 잃은 돈을 되찾겠다고 친구에게 빌리고 약속까지 계속 놓친 이야기야."))
$rows.Add((New-ScenarioRow "v5_d3_case_cue_missed" "v5_d3_case_cue_missed_02" "study" "3" "afternoon" "job_missed" "schedule.job=missed;schedule.homework=pending" 170 "day" 2 "Protagonist" "서연" "message" "" "응. 그냥 넘기면 안 될 것 같아. 지금 읽어볼게."))
$rows.Add((New-ScenarioRow "v5_d3_case_cue_missed" "v5_d3_case_cue_missed_03" "study" "3" "afternoon" "job_missed" "schedule.job=missed;schedule.homework=pending" 170 "day" 3 "Protagonist" "나" "overlay" "" "오늘 서연이가 보내 준 사례에서 돈을 빌린 뒤 일정까지 무너진 부분을 정리하자." -Effects "flag.seoyeon_case_seen:set=true|tutorial:set=study"))
$rows.Add((New-ScenarioRow "v5_d3_study_done" "v5_d3_study_done_01" "study" "3" "evening" "homework_complete" "" 205 "game" 1 "Protagonist" "서연" "message" "" "사례 다시 봤어. 처음 딴 돈보다, 잃은 돈을 되찾으려고 빌린 뒤 학교와 알바까지 놓친 부분이 제일 위험해 보여."))
$rows.Add((New-ScenarioRow "v5_d3_study_done" "v5_d3_study_done_02" "study" "3" "evening" "homework_complete" "" 205 "game" 2 "Seoyeon" "서연" "message" "seoyeon_default" "맞아. 손실을 만회하려고 빌리고 다시 시작한 순간부터 피해가 더 커졌어."))
$rows.Add((New-ScenarioRow "v5_d3_study_done" "v5_d3_study_done_03" "study" "3" "evening" "homework_complete" "" 205 "game" 3 "Seoyeon" "서연" "message" "seoyeon_default" "월요일에는 이 사례랑 광고의 유혹 장치를 발표자료로 만들자."))
$rows.Add((New-ScenarioRow "v5_d3_study_done" "v5_d3_study_done_04" "study" "3" "evening" "homework_complete" "" 205 "game" 4 "Protagonist" "서연" "message" "" "응. 월요일 학교에서 역할 나누고 같이 만들자." -Effects "project.progress:add=1|relation.seoyeon:add=1"))
$rows.Add((New-ScenarioRow "v5_d3_night_done" "v5_d3_night_done_01" "sleep" "3" "21:00" "evening_fill" "schedule.job=complete;schedule.homework=complete" 90 "day" 1 "Protagonist" "나" "overlay" "" "서연에게 사례 분석을 보내고 월요일 약속까지 정했다. 학교와 발표 준비물을 챙기다 보니 21시가 됐다." -Effects "clock:set=21:00" -Purpose "서연과의 메시지가 끝난 뒤 밤 장면으로 전환한다."))
$rows.Add((New-ScenarioRow "v5_d3_night_missed" "v5_d3_night_missed_01" "sleep" "3" "21:00" "evening_fill" "schedule.job=missed;schedule.homework=complete" 89 "day" 1 "Protagonist" "나" "overlay" "" "알바와 수리비 계획은 꼬였지만 사례 분석은 서연에게 보냈다. 내일 학교 준비를 하다 보니 21시가 됐다." -Effects "clock:set=21:00" -Purpose "결근 경로도 메시지를 마친 뒤 밤 장면으로 전환한다."))

# Day 4: Monday, education, project work and the help-or-hide decision.
$rows.Add((New-ScenarioRow "v5_d4_start_stable" "v5_d4_start_stable_01" "main" "4" "7:00" "day_start" "counter.gamble_sessions<3;flag.late_wake_today!=true" 220 "day" 1 "Protagonist" "나" "narration" "" "월요일 아침. 오늘은 학교에서 서연과 발표 자료를 마무리해야 한다." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d4_start_risk" "v5_d4_start_risk_01" "main" "4" "7:00" "day_start" "counter.gamble_sessions>=3;flag.late_wake_today!=true" 221 "day" 1 "Protagonist" "나" "narration" "" "월요일 아침. 도박에 쓴 돈 생각이 먼저 떠올랐지만 오늘은 학교와 조별과제를 더 미룰 수 없다." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d4_school_lesson" "v5_d4_school_lesson_01" "school" "4" "school" "school_complete" "" 225 "game" 1 "Teacher" "담임 선생님" "dialogue" "" "오늘은 온라인 도박 광고가 왜 게임처럼 보이는지, 실제 도박은 무엇으로 구분하는지 발표자료로 정리해 보자."))
$rows.Add((New-ScenarioRow "v5_d4_school_lesson" "v5_d4_school_lesson_02" "school" "4" "school" "school_complete" "" 225 "game" 2 "Seoyeon" "서연" "dialogue" "seoyeon_default" "첫 장에는 출석 보상, 무료 포인트, 레벨처럼 게임에서 익숙한 장치를 넣자. 경계심을 낮추는 데 쓰일 수 있대."))
$rows.Add((New-ScenarioRow "v5_d4_school_lesson" "v5_d4_school_lesson_03" "school" "4" "school" "school_complete" "" 225 "game" 3 "Protagonist" "나" "dialogue" "" "그럼 캐릭터나 레벨이 있으면 전부 도박이라는 뜻이야? 일반 게임이랑 어떻게 구분해?"))
$rows.Add((New-ScenarioRow "v5_d4_school_lesson" "v5_d4_school_lesson_04" "school" "4" "school" "school_complete" "" 225 "game" 4 "Seoyeon" "서연" "dialogue" "seoyeon_default" "그건 아니야. 겉모습보다 실제 돈이나 가치 있는 걸 걸고, 우연한 결과에 따라 돈을 따거나 잃는 구조인지 봐야 한대."))
$rows.Add((New-ScenarioRow "v5_d4_school_lesson" "v5_d4_school_lesson_05" "school" "4" "school" "school_complete" "" 225 "game" 5 "Protagonist" "나" "dialogue" "" "알겠어. 첫 장은 유혹 장치, 두 번째 장은 돈을 거는 구조와 우연한 결과로 나눠서 만들게."))
$rows.Add((New-ScenarioRow "v5_d4_school_lesson" "v5_d4_school_lesson_06" "school" "4" "school" "school_complete" "" 225 "game" 6 "Seoyeon" "서연" "dialogue" "seoyeon_default" "마지막에는 친구가 도박 문제를 털어놨을 때 어떻게 도울지도 넣자. 혼내거나 대신 갚아주는 건 해결이 아니래."))
$rows.Add((New-ScenarioRow "v5_d4_school_lesson" "v5_d4_school_lesson_07" "school" "4" "school" "school_complete" "" 225 "game" 7 "Protagonist" "나" "dialogue" "" "그냥 하지 말라고 세게 말리면 되는 거 아니야?"))
$rows.Add((New-ScenarioRow "v5_d4_school_lesson" "v5_d4_school_lesson_08" "school" "4" "school" "school_complete" "" 225 "game" 8 "Seoyeon" "서연" "dialogue" "seoyeon_worried" "그러면 더 숨길 수도 있대. 왜 말하기 어려웠는지 먼저 듣고, 믿을 만한 어른이나 1336 상담에 같이 연결하는 게 좋대."))
$rows.Add((New-ScenarioRow "v5_d4_school_lesson" "v5_d4_school_lesson_09" "school" "4" "school" "school_complete" "" 225 "game" 9 "Protagonist" "나" "dialogue" "" "말하는 쪽도 이미 겁먹었을 수 있으니까 먼저 듣는 게 필요하겠네. 그 부분은 내가 설명할게." -Purpose "원본의 주인공 질문과 서연의 설명을 압축하지 않고 보존한다."))
$rows.Add((New-ScenarioRow "v5_d4_school_stable" "v5_d4_school_stable_01" "school" "4" "school" "school_complete" "counter.gamble_sessions<3" 210 "game" 1 "Teacher" "담임 선생님" "dialogue" "" "좋아. 주말에 조사한 사례와 상담 정보까지 연결하면 발표 흐름이 분명해지겠다."))
$rows.Add((New-ScenarioRow "v5_d4_school_stable" "v5_d4_school_stable_02" "school" "4" "school" "school_complete" "counter.gamble_sessions<3" 210 "game" 2 "Protagonist" "나" "dialogue" "" "집에 가서 세 부분을 발표자료로 완성하고 서연에게 보내야겠다." -Effects "tutorial:set=study"))
$rows.Add((New-ScenarioRow "v5_d4_school_risk" "v5_d4_school_risk_01" "school" "4" "school" "school_complete" "counter.gamble_sessions>=3" 211 "game" 1 "Teacher" "담임 선생님" "dialogue" "" "손실을 되찾으려고 돈을 빌리거나 학교와 약속을 미루기 시작했다면 혼자 해결하려 하지 말고 바로 도움을 요청해야 해."))
$rows.Add((New-ScenarioRow "v5_d4_school_risk" "v5_d4_school_risk_02" "school" "4" "school" "school_complete" "counter.gamble_sessions>=3" 211 "game" 2 "Protagonist" "나" "narration" "" "오늘 정리한 사례가 내 이야기처럼 들렸다. 지금 말하면 숨긴 일까지 전부 설명해야 한다."))
$rows.Add((New-ScenarioRow "v5_d4_school_risk" "v5_d4_school_risk_03" "school" "4" "school" "school_complete" "counter.gamble_sessions>=3" 211 "game" 3 "Teacher" "담임 선생님" "dialogue" "" "요즘 계속 피곤해 보이는데 무슨 일 있니? 천천히 말해도 괜찮아." "d13_tell_teacher" "선생님께 사실대로 말한다" "선생님, 사실 도박하다 돈을 잃었어요. 혼자서는 멈추기 어려워요." "flag.help_requested:set=true|relation.teacher:add=3" "v5_d4_help_response" "d13_hide_again" "아무 일도 아니라고 한다" "아니에요. 그냥 알바 때문에 피곤해서 그래요." "flag.help_requested:set=false|relation.teacher:add=-2" "v5_d4_hide_result" -Purpose "교육 내용이 주인공 자신의 상황과 겹친 뒤 도움 요청 선택으로 이어진다."))
$rows.Add((New-ScenarioRow "v5_d4_help_response" "v5_d4_help_response_01" "school" "4" "after_school" "v5_d4_help_response" "" 205 "game" 1 "Teacher" "담임 선생님" "dialogue" "" "말해줘서 잘했어. 돈 문제를 도박으로 해결하려 하지 말고 부모님과 상담 선생님께 같이 이야기하자."))
$rows.Add((New-ScenarioRow "v5_d4_help_response" "v5_d4_help_response_02" "school" "4" "after_school" "v5_d4_help_response" "" 205 "game" 2 "Protagonist" "나" "dialogue" "" "네. 무섭지만 더 숨기지는 않을게요. 집에 가서 발표자료도 마무리할게요." -Effects "unlock.counseling:set=true|tutorial:set=study"))
$rows.Add((New-ScenarioRow "v5_d4_hide_result" "v5_d4_hide_result_01" "school" "4" "after_school" "v5_d4_hide_result" "" 205 "game" 1 "Protagonist" "나" "narration" "" "괜찮다고 말하고 교무실을 나왔다. 안도감보다 다시 혼자가 됐다는 생각이 더 크게 남았다. 일단 집에 가서 내일 발표자료부터 마무리하자." -Effects "tutorial:set=study"))
$rows.Add((New-ScenarioRow "v5_d4_study_done_stable" "v5_d4_study_done_stable_01" "study" "4" "evening" "homework_complete" "counter.gamble_sessions<3" 180 "game" 1 "Protagonist" "서연" "message" "" "발표자료 만들었어. 게임처럼 보이게 하는 장치, 도박을 구분하는 기준, 도움받는 방법까지 세 부분으로 나눴어."))
$rows.Add((New-ScenarioRow "v5_d4_study_done_stable" "v5_d4_study_done_stable_02" "study" "4" "evening" "homework_complete" "counter.gamble_sessions<3" 180 "game" 2 "Seoyeon" "서연" "message" "seoyeon_default" "자료 확인했어. 사례랑 1336까지 자연스럽게 이어져서 이해하기 좋다. 내일 발표 전에 역할만 다시 맞추자."))
$rows.Add((New-ScenarioRow "v5_d4_study_done_stable" "v5_d4_study_done_stable_03" "study" "4" "evening" "homework_complete" "counter.gamble_sessions<3" 180 "game" 3 "Protagonist" "서연" "message" "" "응. 내일은 내가 구분 기준이랑 도움받는 방법을 설명할게." -Effects "relation.seoyeon:add=2|schedule.project:set=complete"))
$rows.Add((New-ScenarioRow "v5_d4_study_done_risk" "v5_d4_study_done_risk_01" "study" "4" "evening" "homework_complete" "counter.gamble_sessions>=3" 181 "game" 1 "Protagonist" "서연" "message" "" "늦어서 미안해. 발표자료 지금 보냈어. 유혹 장치랑 도박 구분 기준, 도움받는 방법까지 넣었어."))
$rows.Add((New-ScenarioRow "v5_d4_study_done_risk" "v5_d4_study_done_risk_02" "study" "4" "evening" "homework_complete" "counter.gamble_sessions>=3" 181 "game" 2 "Seoyeon" "서연" "message" "seoyeon_worried" "자료는 확인했어. 내일 발표할 수 있겠어? 요즘 연락이 늦어서 걱정됐어."))
$rows.Add((New-ScenarioRow "v5_d4_study_done_risk" "v5_d4_study_done_risk_03" "study" "4" "evening" "homework_complete" "counter.gamble_sessions>=3" 181 "game" 3 "Protagonist" "서연" "message" "" "응. 걱정하게 해서 미안해. 내일은 피하지 않고 학교 갈게." -Effects "relation.seoyeon:add=1|schedule.project:set=complete"))
$rows.Add((New-ScenarioRow "v5_d4_evening" "v5_d4_evening_01" "main" "4" "evening" "evening_fill" "schedule.homework=complete" 90 "day" 1 "Protagonist" "나" "overlay" "" "발표 준비는 끝났다. 내일은 서연과 정리한 내용을 차분하게 전달하자." -Effects "clock:set=21:00"))

# Day 5: Tuesday, final presentation and explicit result cards.
$rows.Add((New-ScenarioRow "v5_d5_start_recovery" "v5_d5_start_recovery_01" "main" "5" "7:00" "day_start" "flag.help_requested=true;flag.late_wake_today!=true" 230 "game" 1 "Protagonist" "나" "narration" "" "화요일 아침. 어제 선생님께 말한 뒤 부모님과 상담 일정을 잡았다. 문제는 남아 있지만 더 숨기지는 않기로 했다." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d5_start_no_help" "v5_d5_start_no_help_01" "main" "5" "7:00" "day_start" "flag.help_requested!=true;counter.gamble_sessions>=3;flag.late_wake_today!=true" 229 "game" 1 "Protagonist" "나" "narration" "" "화요일 아침. 발표 날인데도 잃은 돈을 되찾을 생각부터 떠올랐다. 어제도 결국 아무에게도 말하지 못했다." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d5_start_prevented" "v5_d5_start_prevented_01" "main" "5" "7:00" "day_start" "counter.gamble_sessions<3;flag.late_wake_today!=true" 228 "game" 1 "Protagonist" "나" "narration" "" "화요일 아침. 오늘은 조별 발표가 있는 날이다. 유혹은 있었지만 해야 할 일을 먼저 끝낼 수 있었다." -Effects "tutorial:set=map"))
$rows.Add((New-ScenarioRow "v5_d5_presentation" "v5_d5_presentation_01" "school" "5" "school" "school_complete" "schedule.project=complete" 240 "game" 1 "Seoyeon" "서연" "dialogue" "seoyeon_default" "그럼 발표 시작할게. 먼저 온라인 도박 광고가 왜 게임처럼 보이는지 설명해 줘."))
$rows.Add((New-ScenarioRow "v5_d5_presentation" "v5_d5_presentation_02" "school" "5" "school" "school_complete" "schedule.project=complete" 240 "game" 2 "Protagonist" "나" "dialogue" "" "출석 보상이나 레벨, 무료 포인트 같은 익숙한 장치로 경계심을 낮춥니다. 하지만 이런 모양만으로 도박인지 판단할 수는 없습니다."))
$rows.Add((New-ScenarioRow "v5_d5_presentation" "v5_d5_presentation_03" "school" "5" "school" "school_complete" "schedule.project=complete" 240 "game" 3 "Seoyeon" "서연" "dialogue" "seoyeon_default" "중요한 건 실제 돈이나 가치 있는 걸 걸고, 우연한 결과에 따라 이익과 손실이 생기는 구조인지 보는 겁니다."))
$rows.Add((New-ScenarioRow "v5_d5_presentation" "v5_d5_presentation_04" "school" "5" "school" "school_complete" "schedule.project=complete" 240 "game" 4 "Teacher" "담임 선생님" "dialogue" "" "그럼 주변 친구가 손실을 되찾으려고 돈까지 빌리고 있다면 어떻게 해야 할까?"))
$rows.Add((New-ScenarioRow "v5_d5_presentation" "v5_d5_presentation_05" "school" "5" "school" "school_complete" "schedule.project=complete" 240 "game" 5 "Protagonist" "나" "dialogue" "" "혼내거나 대신 갚아주기보다 먼저 이야기를 듣고, 믿을 만한 어른이나 도박문제 상담 1336에 함께 도움을 요청해야 합니다." -Purpose "공부 앱에서 익힌 다섯 가지 핵심 내용을 실제 발표 대사로 회수한다."))
$rows.Add((New-ScenarioRow "v5_d5_school_recovery" "v5_d5_school_recovery_01" "school" "5" "school" "school_complete" "flag.help_requested=true;schedule.project=complete" 220 "game" 1 "Seoyeon" "서연" "dialogue" "seoyeon_default" "발표 잘 끝났다. 요즘 힘들어 보였는데도 네 역할은 마무리했네."))
$rows.Add((New-ScenarioRow "v5_d5_school_recovery" "v5_d5_school_recovery_02" "school" "5" "school" "school_complete" "flag.help_requested=true;schedule.project=complete" 220 "game" 2 "Teacher" "담임 선생님" "dialogue" "" "어제 먼저 말해 준 것도 잘한 선택이야. 이제 부모님과 돈 문제, 밀린 일정을 하나씩 정리하자."))
$rows.Add((New-ScenarioRow "v5_d5_school_recovery" "v5_d5_school_recovery_03" "school" "5" "school" "school_complete" "flag.help_requested=true;schedule.project=complete" 220 "game" 3 "Protagonist" "나" "dialogue" "" "네. 잃은 돈을 되찾으려고 다시 도박하지 않고, 지금 상황부터 계획대로 정리할게요." -Next "v5_recovery_goal_router"))
$rows.Add((New-ScenarioRow "v5_recovery_goal_router" "v5_recovery_goal_router_01" "ending" "5" "ending" "v5_recovery_goal_router" "" 219 "game" 1 "System" "" "router" "" "" -Effects "route:v5_recovery_debt if debt>0 else v5_recovery_no_debt"))
$rows.Add((New-ScenarioRow "v5_recovery_debt" "v5_recovery_debt_01" "ending" "5" "ending" "v5_recovery_debt" "" 218 "game" 1 "Protagonist" "나" "dialogue" "" "수리비보다 갚아야 할 돈을 먼저 정리해야 한다. 그래도 이제는 혼자 숨기지 않는다." -Next "ending_recovery"))
$rows.Add((New-ScenarioRow "v5_recovery_no_debt" "v5_recovery_no_debt_01" "ending" "5" "ending" "v5_recovery_no_debt" "" 218 "game" 1 "Protagonist" "나" "dialogue" "" "잃은 돈은 남았지만 더 큰 빚을 만들기 전에 멈췄다. 이제 밀린 일정을 다시 세우자." -Next "ending_recovery"))
$rows.Add((New-ScenarioRow "ending_recovery" "ending_recovery_01" "ending" "5" "ending" "ending_recovery" "" 300 "game" 1 "Narrator" "" "ending" "" "문제는 한 번에 사라지지 않았지만, 도움을 요청한 순간부터 회복은 시작됐다." -Effects "ending:set=recovery" -Purpose "도움 요청을 분명한 회복 결과로 표시한다."))
$rows.Add((New-ScenarioRow "v5_d5_school_no_help" "v5_d5_school_no_help_01" "school" "5" "school" "school_complete" "flag.help_requested!=true;counter.gamble_sessions>=3;schedule.project=complete" 219 "game" 1 "Teacher" "담임 선생님" "dialogue" "" "발표는 끝났지만 네 상태는 그냥 넘길 수 없겠다. 보호자와 같이 이야기하자."))
$rows.Add((New-ScenarioRow "v5_d5_school_no_help" "v5_d5_school_no_help_02" "school" "5" "school" "school_complete" "flag.help_requested!=true;counter.gamble_sessions>=3;schedule.project=complete" 219 "game" 2 "Protagonist" "나" "narration" "" "끝까지 숨기려 했지만 반복한 도박과 끊이지 않는 메시지까지 혼자 감출 수는 없었다."))
$rows.Add((New-ScenarioRow "v5_d5_school_no_help" "v5_d5_school_no_help_03" "school" "5" "school" "school_complete" "flag.help_requested!=true;counter.gamble_sessions>=3;schedule.project=complete" 219 "game" 3 "Narrator" "" "narration" "" "결국 보호자와 학교에 상황이 알려졌고, 불법 도박 문제는 경찰 상담으로까지 이어졌다." -Next "ending_no_help"))
$rows.Add((New-ScenarioRow "ending_no_help" "ending_no_help_01" "ending" "5" "ending" "ending_no_help" "" 300 "game" 1 "Narrator" "" "ending" "" "손실을 혼자 되찾으려 도박을 반복했지만 문제는 해결되지 않았다. 이제 주변의 도움을 받아 돈과 생활을 함께 정리해야 한다." -Effects "ending:set=no_help" -Purpose "지속한 선택의 결과와 도움 필요성을 명확히 표시한다."))
$rows.Add((New-ScenarioRow "v5_d5_school_prevented" "v5_d5_school_prevented_01" "school" "5" "school" "school_complete" "counter.gamble_sessions<3;schedule.project=complete" 218 "game" 1 "Teacher" "담임 선생님" "dialogue" "" "발표 좋았어. 위험 신호와 도움받는 방법을 구체적으로 잘 설명했구나."))
$rows.Add((New-ScenarioRow "v5_d5_school_prevented" "v5_d5_school_prevented_02" "school" "5" "school" "school_complete" "counter.gamble_sessions<3;schedule.project=complete" 218 "game" 2 "Seoyeon" "서연" "dialogue" "seoyeon_default" "자료까지 끝냈잖아. 오늘 같이 발표할 수 있어서 다행이었어."))
$rows.Add((New-ScenarioRow "v5_d5_school_prevented" "v5_d5_school_prevented_03" "school" "5" "school" "school_complete" "counter.gamble_sessions<3;schedule.project=complete" 218 "game" 3 "Protagonist" "나" "dialogue" "" "응. 같이 준비해서 끝내니까 마음이 놓인다. 자료 찾아줘서 고마워." -Next "v5_prevented_goal_router"))
$rows.Add((New-ScenarioRow "v5_d5_school_incomplete_recovery" "v5_d5_school_incomplete_recovery_01" "school" "5" "school" "school_complete" "flag.help_requested=true;schedule.project!=complete" 225 "game" 1 "Seoyeon" "서연" "dialogue" "seoyeon_worried" "네가 맡은 자료가 끝나지 않아서 발표를 제대로 마무리하지 못했어. 어제 무슨 일 있었던 거야?"))
$rows.Add((New-ScenarioRow "v5_d5_school_incomplete_recovery" "v5_d5_school_incomplete_recovery_02" "school" "5" "school" "school_complete" "flag.help_requested=true;schedule.project!=complete" 225 "game" 2 "Teacher" "담임 선생님" "dialogue" "" "발표 준비를 놓친 결과는 책임져야 한다. 그래도 어제 먼저 도움을 요청한 건 잘한 선택이야. 밀린 일정부터 다시 정리하자."))
$rows.Add((New-ScenarioRow "v5_d5_school_incomplete_recovery" "v5_d5_school_incomplete_recovery_03" "school" "5" "school" "school_complete" "flag.help_requested=true;schedule.project!=complete" 225 "game" 3 "Protagonist" "나" "dialogue" "" "미안해. 발표를 망친 건 변명하지 않을게. 도움받으면서 돈과 일정부터 다시 정리하겠습니다." -Next "v5_recovery_goal_router"))
$rows.Add((New-ScenarioRow "v5_d5_school_incomplete_no_help" "v5_d5_school_incomplete_no_help_01" "school" "5" "school" "school_complete" "flag.help_requested!=true;counter.gamble_sessions>=3;schedule.project!=complete" 224 "game" 1 "Teacher" "담임 선생님" "dialogue" "" "맡은 자료가 빠져 발표를 제대로 진행하지 못했다. 요즘 결석과 일정 문제가 이어지는 이유를 보호자와 같이 확인하자."))
$rows.Add((New-ScenarioRow "v5_d5_school_incomplete_no_help" "v5_d5_school_incomplete_no_help_02" "school" "5" "school" "school_complete" "flag.help_requested!=true;counter.gamble_sessions>=3;schedule.project!=complete" 224 "game" 2 "Protagonist" "나" "narration" "" "숨기면 지나갈 줄 알았지만 발표까지 망치고 나니 더는 혼자 감출 수 없었다."))
$rows.Add((New-ScenarioRow "v5_d5_school_incomplete_no_help" "v5_d5_school_incomplete_no_help_03" "school" "5" "school" "school_complete" "flag.help_requested!=true;counter.gamble_sessions>=3;schedule.project!=complete" 224 "game" 3 "Narrator" "" "narration" "" "결국 보호자와 학교에 상황이 알려졌고, 불법 도박 문제는 경찰 상담으로까지 이어졌다." -Next "ending_no_help"))
$rows.Add((New-ScenarioRow "v5_d5_school_incomplete_prevented" "v5_d5_school_incomplete_prevented_01" "school" "5" "school" "school_complete" "counter.gamble_sessions<3;schedule.project!=complete" 223 "game" 1 "Teacher" "담임 선생님" "dialogue" "" "도박을 멈춘 것과 별개로 맡은 자료를 끝내지 못한 건 일정 관리의 결과다. 서연에게 먼저 사과하고 보완 계획을 세우자."))
$rows.Add((New-ScenarioRow "v5_d5_school_incomplete_prevented" "v5_d5_school_incomplete_prevented_02" "school" "5" "school" "school_complete" "counter.gamble_sessions<3;schedule.project!=complete" 223 "game" 2 "Protagonist" "서연" "dialogue" "" "미안해. 내가 맡은 일을 끝내지 못했어. 오늘 안에 빠진 자료를 보완해서 다시 보낼게."))
$rows.Add((New-ScenarioRow "v5_d5_school_incomplete_prevented" "v5_d5_school_incomplete_prevented_03" "school" "5" "school" "school_complete" "counter.gamble_sessions<3;schedule.project!=complete" 223 "game" 3 "Seoyeon" "서연" "dialogue" "seoyeon_worried" "다음에는 늦기 전에 먼저 말해 줘. 오늘은 같이 보완해 보자." -Next "v5_prevented_goal_router"))
$rows.Add((New-ScenarioRow "v5_prevented_goal_router" "v5_prevented_goal_router_01" "ending" "5" "ending" "v5_prevented_goal_router" "" 217 "game" 1 "System" "" "router" "" "" -Effects "route:v5_prevented_goal_full if counter.job_attendance>=2;counter.gamble_sessions=0 else v5_prevented_goal_mixed_router"))
$rows.Add((New-ScenarioRow "v5_prevented_goal_mixed_router" "v5_prevented_goal_mixed_router_01" "ending" "5" "ending" "v5_prevented_goal_mixed_router" "" 216 "game" 1 "System" "" "router" "" "" -Effects "route:v5_prevented_goal_mixed if cash>=150000 else v5_prevented_goal_short"))
$rows.Add((New-ScenarioRow "v5_prevented_goal_full" "v5_prevented_goal_full_01" "ending" "5" "ending" "v5_prevented_goal_full" "" 215 "game" 1 "Protagonist" "나" "dialogue" "" "주말 근무를 이틀 다 나간 덕분에 수리비 15만 원을 채웠다. 오래 걸렸지만 계획대로 모은 돈이었다." -Next "ending_prevented"))
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

@(
    [pscustomobject]@{ day="1"; activity_title="조별과제 역할 확인"; progress_label="과제 계획"; activity_text="오늘 서연과 나눈 역할을 정리하는 중..."; question="월요일까지 내가 맡아 정리할 내용은 무엇이었지?"; choice_a="도박 피해 사례와 도움받을 곳"; choice_b="카페 메뉴와 근무 시간"; choice_c="발표 배경 음악과 영상"; answer_index="0"; correct_text="맞아. 피해 사례와 도움받을 곳을 조사하고 출처까지 적기로 했지."; wrong_text="오늘 서연과 나눈 역할을 다시 떠올려 보자. 내가 맡은 건 피해 사례와 도움받을 곳이었다." }
    [pscustomobject]@{ day="2"; activity_title="도박 문제 상담처 조사"; progress_label="상담 번호"; activity_text="서연에게 보낼 공식 상담 정보를 찾는 중..."; question="도박 문제로 상담받을 수 있는 전화번호는 무엇일까?"; choice_a="1333"; choice_b="1336"; choice_c="1338"; answer_index="1"; correct_text="맞아. 도박 문제 상담은 국번 없이 1336이야."; wrong_text="번호를 다시 확인하자. 도박 문제 상담은 국번 없이 1336이야." }
    [pscustomobject]@{ day="2"; activity_title="도박 문제 상담처 조사"; progress_label="상담 내용"; activity_text="상담을 통해 받을 수 있는 도움을 정리하는 중..."; question="혼자 도박 문제를 해결하기 어렵다면 가장 적절한 행동은 무엇일까?"; choice_a="손실을 만회할 때까지 아무에게도 말하지 않는다."; choice_b="믿을 만한 어른이나 1336에 상담을 요청한다."; choice_c="친구에게 돈만 빌려 조용히 해결한다."; answer_index="1"; correct_text="그래. 혼자 숨기기보다 믿을 만한 어른이나 전문 상담에 연결하는 게 중요해."; wrong_text="돈만 빌리거나 숨기면 문제가 더 커질 수 있어. 도움을 요청하는 방법을 다시 보자." }
    [pscustomobject]@{ day="3"; activity_title="서연이 보낸 사례 분석"; progress_label="시작 계기"; activity_text="오늘 서연이가 보내 준 사례를 다시 읽는 중..."; question="사례 속 학생이 도박을 계속하게 된 첫 계기는 무엇이었을까?"; choice_a="무료 포인트로 조금 딴 경험"; choice_b="친구에게 혼난 경험"; choice_c="상담을 받은 경험"; answer_index="0"; correct_text="맞아. 처음의 작은 이득이 다음에도 쉽게 딸 수 있다는 기대를 만들었어."; wrong_text="오늘 서연이가 보내 준 사례의 시작을 다시 보자. 무료 포인트로 얻은 작은 이득이 계기였어." }
    [pscustomobject]@{ day="3"; activity_title="서연이 보낸 사례 분석"; progress_label="위험 신호"; activity_text="사례에서 피해가 커진 지점을 표시하는 중..."; question="도박 문제가 더 깊어졌다는 가장 분명한 신호는 무엇일까?"; choice_a="친구와 게임 이야기를 했다."; choice_b="주말에 늦잠을 잤다."; choice_c="손실을 만회하려 돈을 빌렸다."; answer_index="2"; correct_text="그래. 손실을 되찾으려고 돈을 빌리고 다시 도박한 순간부터 피해가 더 커졌어."; wrong_text="오늘 서연이가 보내 준 사례에서 돈과 도박이 어떻게 이어졌는지 다시 살펴보자." }
    [pscustomobject]@{ day="4"; activity_title="조별과제 발표자료 제작"; progress_label="유혹 장치"; activity_text="발표자료의 첫 번째 부분을 만드는 중..."; question="도박 사이트가 게임처럼 보이게 만드는 유혹 장치는 무엇일까?"; choice_a="레벨, 출석 보상, 무료 포인트"; choice_b="손실과 위험을 알리는 경고"; choice_c="이용을 멈추는 차단 기능"; answer_index="0"; correct_text="맞아. 게임에서 익숙한 보상처럼 보여 경계심을 낮출 수 있어."; wrong_text="위험 경고나 차단 기능은 이용을 멈추게 하는 장치야. 유혹에 쓰이는 요소를 다시 골라 보자." }
    [pscustomobject]@{ day="4"; activity_title="조별과제 발표자료 제작"; progress_label="구분 기준"; activity_text="발표자료의 두 번째 부분을 만드는 중..."; question="겉모습이 비슷할 때 도박인지 구분하는 핵심 기준은 무엇일까?"; choice_a="캐릭터와 레벨이 있는지"; choice_b="실제 돈을 걸고 우연한 결과로 손익이 갈리는지"; choice_c="화면 효과와 음악이 화려한지"; answer_index="1"; correct_text="그래. 겉모습보다 돈을 거는 구조와 우연한 결과에 따른 손익을 봐야 해."; wrong_text="캐릭터나 화려한 효과는 일반 게임에도 있어. 실제 돈과 결과의 구조를 다시 생각해 보자." }
    [pscustomobject]@{ day="4"; activity_title="조별과제 발표자료 제작"; progress_label="도움 방법"; activity_text="발표자료의 마지막 부분을 만드는 중..."; question="친구가 도박 문제를 털어놓으면 어떻게 돕는 것이 좋을까?"; choice_a="세게 혼내서 다시는 말하지 못하게 한다."; choice_b="빚을 대신 갚아주고 아무에게도 알리지 않는다."; choice_c="먼저 듣고 믿을 만한 어른이나 1336에 함께 연결한다."; answer_index="2"; correct_text="맞아. 먼저 이야기를 듣고 믿을 만한 어른과 전문 상담에 연결하는 게 중요해."; wrong_text="혼내거나 돈만 대신 갚아주면 더 숨길 수 있어. 도움을 연결하는 방법을 다시 보자." }
) | Export-Csv -LiteralPath (Join-Path $resourcePath "StudyActivities.csv") -NoTypeInformation -Encoding utf8BOM -UseQuotes Always

$flowKeep = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($row in $rows) { [void]$flowKeep.Add($row.scene_id) }
$oldFlow = Import-Csv -LiteralPath (Join-Path $resourcePath "ScenarioV3Flow.csv")
$flowRows = [System.Collections.Generic.List[object]]::new()
foreach ($row in $oldFlow) {
    if ($flowKeep.Contains($row.scene_id)) { $flowRows.Add($row) }
}
$customReturnToTablet = @(
    "v5_d2_start", "v5_d2_job", "v5_d2_minjae_after_miss", "v5_d2_missed_daytime", "v5_d2_study_cue_done", "v5_d2_study_cue_missed", "v5_d2_study_done", "v5_d2_night_done", "v5_d2_night_missed",
    "v5_d3_start", "v5_d3_job_good", "v5_d3_job_return", "v5_d3_minjae_after_miss", "v5_d3_missed_daytime_first", "v5_d3_missed_daytime_fired", "v5_d3_case_cue_done", "v5_d3_case_cue_missed", "v5_d3_study_done", "v5_d3_night_done", "v5_d3_night_missed",
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
