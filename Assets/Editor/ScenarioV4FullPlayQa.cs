#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using Dobak.App.Map;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UI;

public static class ScenarioV4FullPlayQa
{
    private enum Route
    {
        Recovery, Prevention, NoGamble, NoHelp, Collapse, NoFunds, MinjaeDebt, SeojunDebt,
        LoanHeld, RepeatLoss, ProjectFail, MixedA, MixedB, MixedC
    }

    private static readonly Route[] AllRoutes =
    {
        Route.Recovery,
        Route.Prevention,
        Route.NoGamble,
        Route.NoHelp,
        Route.Collapse,
        Route.NoFunds,
        Route.MinjaeDebt,
        Route.SeojunDebt,
        Route.LoanHeld,
        Route.RepeatLoss,
        Route.ProjectFail,
        Route.MixedA,
        Route.MixedB,
        Route.MixedC
    };

    private const string MainScene = "Assets/Tablet/TabletUI.unity";
    private static Route route;
    private static double startedAt;
    private static double nextActionAt;
    private static double nextDebugAt;
    private static string pendingMapTarget = string.Empty;
    private static string lastLine = string.Empty;
    private static string lastCapturedScene = string.Empty;
    private static readonly HashSet<int> capturedDays = new HashSet<int>();
    private static readonly HashSet<int> capturedQuizDays = new HashSet<int>();
    private static readonly HashSet<int> capturedOfferDays = new HashSet<int>();
    private static bool quizOpen;
    private static bool testedWrongAnswer;
    private static bool replyBubbleVerified;
    private static bool capturedChoiceDebug;
    private static bool capturedManagerHeader;
    private static double choiceSubmittedAt;
    private static bool failed;
    private static bool previousOptionsEnabled;
    private static EnterPlayModeOptions previousOptions;
    private static bool runAllRoutes;
    private static bool anyRouteFailed;
    private static Route? queuedRoute;
    private static int observedDay;
    private static bool routeCompleted;
    private static bool repeatLossObserved;
    private static bool cafeSceneLocationChecked;
    private static bool projectFailureObserved;
    private static bool seoyeonRepairObserved;
    private static bool preventedReturnHomeObserved;
    private static string expectedConsecutiveGambleScene = string.Empty;
    private static string lastBlockingDialogue = string.Empty;
    private static readonly HashSet<string> observedScenes = new HashSet<string>();
    private static bool jobGateAttempted;
    private static bool jobGateVerified;
    private static bool weekendStudyGateAttempted;
    private static bool weekendStudyGateVerified;
    private static string expectedScheduleGateText = string.Empty;

    private const double UiSettleDelay = 0.12d;
    private const double SceneSettleDelay = 0.7d;
    private const double ChoiceSettleDelay = 0.45d;

    public static void RunRecovery() => Run(Route.Recovery);
    public static void RunPrevention() => Run(Route.Prevention);
    public static void RunNoGamble() => Run(Route.NoGamble);
    public static void RunNoHelp() => Run(Route.NoHelp);
    public static void RunCollapse() => Run(Route.Collapse);
    public static void RunNoFunds() => Run(Route.NoFunds);
    public static void RunProjectFail() => Run(Route.ProjectFail);
    public static void RunRepeatLoss() => Run(Route.RepeatLoss);
    public static void RunAll()
    {
        runAllRoutes = true;
        anyRouteFailed = false;
        queuedRoute = null;
        Run(Route.Recovery);
    }

    public static void ResumeQueuedRoute()
    {
        if (!queuedRoute.HasValue || EditorApplication.isPlaying ||
            EditorApplication.isPlayingOrWillChangePlaymode)
            return;

        Route next = queuedRoute.Value;
        queuedRoute = null;
        Run(next);
    }

    private static void ResumeQueuedRouteWhenReady()
    {
        if (!queuedRoute.HasValue)
        {
            EditorApplication.update -= ResumeQueuedRouteWhenReady;
            return;
        }

        if (EditorApplication.isPlaying || EditorApplication.isPlayingOrWillChangePlaymode)
            return;

        EditorApplication.update -= ResumeQueuedRouteWhenReady;
        ResumeQueuedRoute();
    }

    public static void RunRemainingFromNoHelp()
    {
        runAllRoutes = true;
        anyRouteFailed = false;
        Run(Route.NoHelp);
    }

    public static void RunRemainingFromSeojunDebt()
    {
        runAllRoutes = true;
        anyRouteFailed = false;
        Run(Route.SeojunDebt);
    }

    public static void AbortForRestart()
    {
        runAllRoutes = false;
        EditorApplication.update -= Tick;
        EditorApplication.playModeStateChanged -= OnPlayModeChanged;
        if (EditorApplication.isPlaying || EditorApplication.isPlayingOrWillChangePlaymode)
            EditorApplication.ExitPlaymode();
    }

    private static void Run(Route selectedRoute)
    {
        route = selectedRoute;
        failed = false;
        quizOpen = false;
        testedWrongAnswer = false;
        replyBubbleVerified = false;
        capturedChoiceDebug = false;
        capturedManagerHeader = false;
        choiceSubmittedAt = 0d;
        routeCompleted = false;
        repeatLossObserved = false;
        cafeSceneLocationChecked = false;
        projectFailureObserved = false;
        seoyeonRepairObserved = false;
        preventedReturnHomeObserved = false;
        expectedConsecutiveGambleScene = string.Empty;
        lastBlockingDialogue = string.Empty;
        observedScenes.Clear();
        jobGateAttempted = false;
        jobGateVerified = false;
        weekendStudyGateAttempted = false;
        weekendStudyGateVerified = false;
        expectedScheduleGateText = string.Empty;
        pendingMapTarget = string.Empty;
        lastLine = string.Empty;
        lastCapturedScene = string.Empty;
        observedDay = 0;
        capturedDays.Clear();
        capturedQuizDays.Clear();
        capturedOfferDays.Clear();
        string save = Path.Combine(Application.persistentDataPath, "scenario_v3_history.json");
        if (File.Exists(save))
            File.Delete(save);

        previousOptionsEnabled = EditorSettings.enterPlayModeOptionsEnabled;
        previousOptions = EditorSettings.enterPlayModeOptions;
        EditorSettings.enterPlayModeOptionsEnabled = true;
        EditorSettings.enterPlayModeOptions = EnterPlayModeOptions.DisableDomainReload;
        EditorSceneManager.OpenScene(MainScene, OpenSceneMode.Single);
        EditorApplication.playModeStateChanged -= OnPlayModeChanged;
        EditorApplication.playModeStateChanged += OnPlayModeChanged;
        EditorApplication.EnterPlaymode();
    }

    private static void OnPlayModeChanged(PlayModeStateChange state)
    {
        if (state == PlayModeStateChange.EnteredPlayMode)
        {
            EditorApplication.isPaused = false;
            startedAt = EditorApplication.timeSinceStartup;
            nextActionAt = startedAt + 1d;
            nextDebugAt = startedAt + 5d;
            EditorApplication.update -= Tick;
            EditorApplication.update += Tick;
        }
        else if (state == PlayModeStateChange.EnteredEditMode)
        {
            EditorApplication.update -= Tick;
            EditorApplication.playModeStateChanged -= OnPlayModeChanged;
            EditorSettings.enterPlayModeOptionsEnabled = previousOptionsEnabled;
            EditorSettings.enterPlayModeOptions = previousOptions;
            if (!routeCompleted && !failed)
            {
                failed = true;
                Debug.LogError($"[SCENARIO V4 {route.ToString().ToUpperInvariant()} QA] Play mode ended before the route reached an ending.");
            }
            Debug.Log(failed
                ? $"[SCENARIO V4 {route.ToString().ToUpperInvariant()} QA] FAIL"
                : $"[SCENARIO V4 {route.ToString().ToUpperInvariant()} QA] PASS");
            anyRouteFailed |= failed;
            int routeIndex = Array.IndexOf(AllRoutes, route);
            if (runAllRoutes && routeIndex >= 0 && routeIndex < AllRoutes.Length - 1)
            {
                queuedRoute = AllRoutes[routeIndex + 1];
                EditorApplication.update -= ResumeQueuedRouteWhenReady;
                EditorApplication.update += ResumeQueuedRouteWhenReady;
                return;
            }

            if (runAllRoutes)
            {
                Debug.Log(anyRouteFailed
                    ? "[SCENARIO V4 ALL ROUTES QA] FAIL"
                    : "[SCENARIO V4 ALL ROUTES QA] PASS");
                runAllRoutes = false;
                queuedRoute = null;
            }
            if (Application.isBatchMode)
                EditorApplication.Exit(anyRouteFailed ? 2 : 0);
        }
    }

    private static void Tick()
    {
        if (EditorApplication.timeSinceStartup - startedAt > 420d)
        {
            Fail("Timed out before reaching an ending.");
            EditorApplication.ExitPlaymode();
            return;
        }
        if (EditorApplication.timeSinceStartup < nextActionAt)
            return;

        ScenarioV3Director director = UnityEngine.Object.FindAnyObjectByType<ScenarioV3Director>();
        GameFlowManager flow = GameFlowManager.Instance;
        AppWindow apps = UnityEngine.Object.FindAnyObjectByType<AppWindow>();
        if (director == null || flow == null || apps == null || !director.IsReady)
            return;

        if (observedDay != flow.CurrentDay)
        {
            observedDay = flow.CurrentDay;
            quizOpen = false;
            pendingMapTarget = string.Empty;
        }

        if (EditorApplication.timeSinceStartup >= nextDebugAt)
        {
            FieldInfo transitionField = typeof(ScenarioV3Director).GetField("sceneTransitionInProgress",
                BindingFlags.Instance | BindingFlags.NonPublic);
            bool sceneTransition = transitionField != null && (bool)transitionField.GetValue(director);
            ScenarioV3Line pendingOutgoing = GetPrivate<ScenarioV3Line>(director, "pendingOutgoingLine");
            bool waitingIncomingRead = GetPrivateValue<bool>(director, "waitingForIncomingMessageRead");
            Coroutine incomingCoroutine = GetPrivate<Coroutine>(director, "incomingMessageCoroutine");
            DialogueManager dialogue = UnityEngine.Object.FindAnyObjectByType<DialogueManager>();
            FieldInfo waitingMessageCloseField = typeof(ScenarioV3Director).GetField("waitingForMessageSceneClose",
                BindingFlags.Instance | BindingFlags.NonPublic);
            bool waitingMessageClose = waitingMessageCloseField != null &&
                                       (bool)waitingMessageCloseField.GetValue(director);
            Queue<ScenarioV3Scene> queuedScenes = GetPrivate<Queue<ScenarioV3Scene>>(director, "sceneQueue");
            ScenarioV3FinalRuntimeFix runtimeFix = UnityEngine.Object.FindAnyObjectByType<ScenarioV3FinalRuntimeFix>();
            GameObject choiceOverlay = GetPrivate<GameObject>(runtimeFix, "choiceOverlay");
            ScenarioV3Line choiceOverlayLine = GetPrivate<ScenarioV3Line>(runtimeFix, "choiceOverlayLine");
            bool choiceOverlayBusy = runtimeFix != null && GetPrivateValue<bool>(runtimeFix, "choiceOverlayBusy");
            TMP_Text narrationBody = GetPrivate<TMP_Text>(flow, "narrationBodyText");
            CanvasGroup fade = GetPrivate<CanvasGroup>(flow, "fadeGroup");
            Debug.Log($"[SCENARIO V4 {route}] day={flow.CurrentDay} hour={flow.CurrentHour} " +
                      $"scene={director.ActiveSceneId}/{director.ActiveLineId} choices={director.CurrentChoices.Count} " +
                      $"location={flow.CurrentLocation} school={flow.IsSchoolDone} study={flow.IsHomeworkDone} " +
                      $"job={flow.IsJobDone} project={director.GetState("schedule.project")} " +
                      $"app={apps.CurrentAppType} pendingMap={pendingMapTarget} quiz={quizOpen} " +
                      $"sceneTransition={sceneTransition} pendingOutgoing={pendingOutgoing?.id} " +
                      $"waitingIncomingRead={waitingIncomingRead} incomingTyping={incomingCoroutine != null} " +
                      $"chatSpeaker={dialogue?.CurrentSpeaker} " +
                      $"waitingMessageClose={waitingMessageClose} queued={queuedScenes?.Count ?? 0} " +
                      $"choiceOverlay={choiceOverlay?.activeInHierarchy}/{choiceOverlayLine?.id}/{choiceOverlayBusy} " +
                      $"eveningFilled={director.GetState("evening_filled")} bedtimeCued={director.GetState("bedtime_cued")} " +
                      $"narration='{narrationBody?.text}' fade={fade?.alpha:0.00}/{fade?.blocksRaycasts}");
            nextDebugAt = EditorApplication.timeSinceStartup + 5d;
        }

        if (flow.IsGameEnded)
        {
            Capture($"ending-{route.ToString().ToLowerInvariant()}.png");
            Expect(flow.CurrentDay == 5, $"Ending occurred on day {flow.CurrentDay}, not day 5.");
            Expect(replyBubbleVerified, "No outgoing reply bubble was observed during the run.");
            string duplicateChoices = string.Join(", ", director.ChoiceHistory
                .GroupBy(choice => choice.choiceId + "|" + choice.day + "|" + choice.time)
                .Where(group => group.Count() > 1)
                .Select(group => group.Key + " [" + string.Join(" / ", group.Select(record =>
                    record.sceneId + ":" + record.lineId)) + "]"));
            Expect(string.IsNullOrEmpty(duplicateChoices),
                "A scenario choice was submitted more than once: " + duplicateChoices);
            if (route != Route.ProjectFail)
            {
                Expect(string.Equals(director.GetState("schedule.project"), "complete",
                        StringComparison.OrdinalIgnoreCase),
                    $"Group project ended as {director.GetState("schedule.project")} instead of complete.");
            }
            else
            {
                Expect(int.Parse(director.GetState("counter.homework_failures")) >= 1,
                    "Project-failure route did not record the missed day-4 study task.");
                Expect(!string.Equals(director.GetState("schedule.project"), "complete",
                        StringComparison.OrdinalIgnoreCase),
                    "Project-failure route incorrectly marked the group project complete.");
            }
            if (route == Route.Recovery)
            {
                ExpectWeekendScheduleScenes("done");
                Expect(director.GetState("ending") == "recovery", $"Expected recovery ending, got {director.GetState("ending")}.");
                Expect(director.GetState("flag.help_requested") == "true", "Teacher counseling was not requested.");
                Expect(int.Parse(director.GetState("counter.gamble_sessions")) >= 3,
                    "Recovery route did not reach the high-risk branch.");
            }
            else if (route == Route.Prevention)
            {
                Expect(director.GetState("ending") == "prevented", $"Expected prevention ending, got {director.GetState("ending")}.");
                int sessions = int.Parse(director.GetState("counter.gamble_sessions"));
                Expect(sessions > 0 && sessions < 3, $"Prevention route recorded {sessions} sessions.");
            }
            else if (route == Route.NoGamble)
            {
                Expect(director.GetState("ending") == "prevented", $"Expected prevented ending, got {director.GetState("ending")}.");
                Expect(int.Parse(director.GetState("counter.gamble_sessions")) == 0,
                    "No-gamble route incorrectly recorded a gambling session.");
            }
            else if (route == Route.NoHelp)
            {
                ExpectWeekendScheduleScenes("done");
                Expect(director.GetState("ending") == "no_help", $"Expected no-help ending, got {director.GetState("ending")}.");
                Expect(director.GetState("flag.help_requested") != "true", "No-help route unexpectedly requested counseling.");
                Expect(int.Parse(director.GetState("counter.gamble_sessions")) >= 3,
                    "No-help route did not reach the high-risk branch.");
            }
            else if (route == Route.Collapse)
            {
                ExpectWeekendScheduleScenes("missed");
                Expect(jobGateVerified, "Weekend gambling was not verified as blocked before the job schedule.");
                Expect(weekendStudyGateVerified, "Weekend gambling was not verified as blocked before study.");
                Expect(director.GetState("ending") == "collapse", $"Expected collapse ending, got {director.GetState("ending")}.");
                Expect(int.Parse(director.GetState("counter.job_failures")) >= 2,
                    "Collapse route did not record both missed weekend shifts.");
                Expect(int.Parse(director.GetState("counter.gamble_sessions")) == 0,
                    "Stable collapse route unexpectedly recorded a gambling session.");
            }
            else if (route == Route.MinjaeDebt)
            {
                Expect(director.GetState("borrowed.minjae") == "true", "Minjae-debt route never borrowed from Minjae.");
            }
            else if (route == Route.SeojunDebt || route == Route.LoanHeld)
            {
                Expect(director.GetState("borrowed.seojun") == "true", $"{route} route never borrowed from Seojun.");
                if (route == Route.LoanHeld)
                    Expect(flow.CurrentDebt > 0, "LoanHeld route unexpectedly repaid every debt.");
            }
            else if (route == Route.RepeatLoss)
            {
                Expect(repeatLossObserved, "Repeat-loss route never displayed gamble_repeat_loss.");
            }
            routeCompleted = true;
            EditorApplication.ExitPlaymode();
            return;
        }

        if (!string.IsNullOrEmpty(director.ActiveSceneId))
            observedScenes.Add(director.ActiveSceneId);

        GameObject blockingNarration = GameObject.Find("Narration Dialogue");
        if (blockingNarration != null && blockingNarration.activeInHierarchy)
        {
            TMP_Text title = GetPrivate<TMP_Text>(flow, "narrationTitleText");
            TMP_Text body = GetPrivate<TMP_Text>(flow, "narrationBodyText");
            if (!string.IsNullOrEmpty(expectedScheduleGateText))
            {
                bool matched = body != null && body.text.Contains(expectedScheduleGateText);
                Expect(matched, $"Expected schedule gate dialogue containing '{expectedScheduleGateText}', got '{body?.text}'.");
                if (expectedScheduleGateText == "알바부터 다녀오자")
                    jobGateVerified = matched;
                else if (expectedScheduleGateText == "공부부터 끝내자")
                    weekendStudyGateVerified = matched;
                expectedScheduleGateText = string.Empty;
            }
            string dialogueKey = $"{title?.text}\n{body?.text}";
            if (dialogueKey != lastBlockingDialogue)
            {
                lastBlockingDialogue = dialogueKey;
                Debug.Log($"[SCENARIO V4 DIALOGUE] {dialogueKey.Replace('\n', ' ')}");
                Capture($"dialogue-{Safe(director.ActiveSceneId + "-" + director.ActiveLineId + "-" + flow.CurrentDay)}.png");
            }

            Button continueButton = GetPrivate<Button>(flow, "narrationContinueButton");
            if (continueButton == null || !continueButton.gameObject.activeInHierarchy)
            {
                Fail("A blocking narration was visible without an active Continue button.");
                EditorApplication.ExitPlaymode();
                return;
            }
            DismissNarration(flow);
            nextActionAt = EditorApplication.timeSinceStartup + UiSettleDelay;
            return;
        }

        if (!string.IsNullOrEmpty(director.ActiveSceneId))
        {
            observedScenes.Add(director.ActiveSceneId);
            if (!string.IsNullOrEmpty(expectedConsecutiveGambleScene))
            {
                Expect(director.ActiveSceneId == expectedConsecutiveGambleScene,
                    $"Consecutive gambling returned to {director.ActiveSceneId} instead of {expectedConsecutiveGambleScene}.");
                expectedConsecutiveGambleScene = string.Empty;
            }
            if (director.ActiveSceneId == "gamble_repeat_loss")
                repeatLossObserved = true;
            if (director.ActiveSceneId == "d8_project_bad")
                projectFailureObserved = true;
            if (director.ActiveSceneId == "d14_seoyeon_bad")
                seoyeonRepairObserved = true;
            if (director.ActiveSceneId == "d14_prevented_return_home")
                preventedReturnHomeObserved = true;
            if (!cafeSceneLocationChecked &&
                (director.ActiveSceneId == "d11_minjae_cafe" || director.ActiveSceneId == "d11_minjae_debt_cafe"))
            {
                cafeSceneLocationChecked = true;
                Expect(flow.CurrentLocation == "카페",
                    $"{director.ActiveSceneId} started at {flow.CurrentLocation} instead of 카페.");
            }
            HandleStory(director, apps);
            return;
        }

        GameObject transientNovel = GetPrivate<GameObject>(director, "novelPanel");
        if (transientNovel != null && transientNovel.activeInHierarchy)
        {
            Capture($"transient-novel-{flow.CurrentDay:00}-{flow.CurrentHour:00}.png");
            GetPrivate<Button>(director, "continueButton")?.onClick.Invoke();
            nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
            return;
        }

        if (!string.IsNullOrEmpty(pendingMapTarget))
        {
            CompleteMapAction();
            return;
        }

        if (director.HasPendingMessageAction)
        {
            if (apps.CurrentAppType != AppType.Message)
            {
                OpenAppImmediate(apps, AppType.Message);
            }
            else
            {
                Button borrowSend = FindButtonWithText("돈을 빌려 달라고 메시지 보낸다");
                if (borrowSend != null)
                {
                    borrowSend.onClick.Invoke();
                    nextActionAt = EditorApplication.timeSinceStartup + ChoiceSettleDelay;
                    return;
                }
            }
            nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
            return;
        }

        Button deferRepayment = FindButtonWithText("지금은 미룬다");
        if (deferRepayment != null)
        {
            deferRepayment.onClick.Invoke();
            nextActionAt = EditorApplication.timeSinceStartup + ChoiceSettleDelay;
            return;
        }

        // The real home launcher asks for one final confirmation before entering
        // the fixed-result gambling sequence. Confirm it just as a player would.
        Button gambleConfirmation = FindButtonWithText("한다");
        if (gambleConfirmation != null)
        {
            gambleConfirmation.onClick.Invoke();
            nextActionAt = EditorApplication.timeSinceStartup + ChoiceSettleDelay;
            return;
        }

        if (ShouldStartGamble(director, flow.CurrentDay))
        {
            quizOpen = false;
            apps.CloseCurrentApp();
            Button launcher = FindActiveButton("Gambling Launcher");
            if (launcher == null)
            {
                Fail("The gambling app is unlocked, but its home launcher is missing.");
                return;
            }
            if (capturedOfferDays.Add(flow.CurrentDay))
                Capture($"gambling-icon-day-{flow.CurrentDay:00}.png");
            // Exercise the same unified launcher path that players use. Calling the
            // director directly skips schedule and late-night guards owned by the UI.
            launcher.onClick.Invoke();
            nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
            return;
        }
        if (quizOpen)
        {
            HandleQuiz(flow, apps);
            return;
        }

        if (capturedDays.Add(flow.CurrentDay))
            Capture($"day-{flow.CurrentDay:00}-tablet.png");

        if (flow.IsWeekend)
        {
            if (!flow.IsJobDone)
            {
                if (route == Route.Collapse && flow.CurrentDay == 2 && !jobGateAttempted)
                {
                    Button launcher = FindActiveButton("Gambling Launcher");
                    if (launcher == null)
                    {
                        Fail("Gambling launcher was missing while testing the weekend job gate.");
                        return;
                    }
                    jobGateAttempted = true;
                    expectedScheduleGateText = "알바부터 다녀오자";
                    launcher.onClick.Invoke();
                    nextActionAt = EditorApplication.timeSinceStartup + UiSettleDelay;
                    return;
                }
                bool skipShift = (route == Route.Collapse && (flow.CurrentDay == 2 || flow.CurrentDay == 3)) ||
                                 (route == Route.NoFunds && flow.CurrentDay == 2);
                if (skipShift)
                    flow.V3SetClock(route == Route.Collapse ? "10:00" : "14:00");
                BeginMapAction(apps, "카페");
                return;
            }
            if (flow.V3HasStudyToday && !flow.IsHomeworkDone)
            {
                if (flow.CurrentLocation != "집")
                {
                    BeginMapAction(apps, "집");
                    return;
                }

                if (route == Route.Collapse && flow.CurrentDay == 2 && !weekendStudyGateAttempted)
                {
                    Dictionary<AppType, GameObject> dots = GetPrivate<Dictionary<AppType, GameObject>>(flow, "appAttentionDots");
                    Expect(dots != null && dots.TryGetValue(AppType.Study, out GameObject studyDot) &&
                           studyDot != null && studyDot.activeInHierarchy,
                        "The weekend study attention dot was not visible after the missed job was resolved.");
                    Button launcher = FindActiveButton("Gambling Launcher");
                    if (launcher == null)
                    {
                        Fail("Gambling launcher was missing while testing the weekend study gate.");
                        return;
                    }
                    weekendStudyGateAttempted = true;
                    expectedScheduleGateText = "공부부터 끝내자";
                    launcher.onClick.Invoke();
                    nextActionAt = EditorApplication.timeSinceStartup + UiSettleDelay;
                    return;
                }

                OpenAppImmediate(apps, AppType.Study);
                quizOpen = true;
                nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
                return;
            }
        }
        else
        {
            if (!flow.IsSchoolDone)
            {
                BeginMapAction(apps, "학교");
                return;
            }
            if (flow.V3HasStudyToday && !flow.IsHomeworkDone)
            {
                bool skipProjectWork = route == Route.ProjectFail && flow.CurrentDay == 4;
                if (skipProjectWork)
                {
                    if (flow.CurrentHour < 21)
                    {
                        flow.V3SetClock("21:00");
                        nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
                        return;
                    }
                }
                else if (flow.CurrentLocation != "집")
                {
                    BeginMapAction(apps, "집");
                    return;
                }
                else
                {
                    OpenAppImmediate(apps, AppType.Study);
                    quizOpen = true;
                    nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
                    return;
                }
            }
        }

        if (!flow.CanSleepNow)
        {
            nextActionAt = EditorApplication.timeSinceStartup + UiSettleDelay;
            return;
        }

        flow.Sleep();
        nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
    }

    private static void HandleStory(ScenarioV3Director director, AppWindow apps)
    {
        if (choiceSubmittedAt > 0d)
        {
            if (EditorApplication.timeSinceStartup - choiceSubmittedAt < ChoiceSettleDelay)
                return;
            choiceSubmittedAt = 0d;
        }

        DialogueManager visibleDialogue = GetPrivate<DialogueManager>(director, "dialogue");
        if (!capturedManagerHeader && route == Route.Collapse && apps.CurrentAppType == AppType.Message &&
            visibleDialogue != null && visibleDialogue.IsConversationOpen(SpeakerType.CafeManager))
        {
            capturedManagerHeader = true;
            Capture("message-manager-header.png");
        }

        if (director.ActiveLineId != lastLine)
        {
            lastLine = director.ActiveLineId;
            nextActionAt = EditorApplication.timeSinceStartup + UiSettleDelay;
            if (director.ActiveSceneId != lastCapturedScene && ShouldCaptureScene(director.ActiveSceneId) &&
                !RequiresSettledNovelCapture(director.ActiveSceneId))
            {
                lastCapturedScene = director.ActiveSceneId;
                Capture($"scene-{Safe(director.ActiveSceneId)}.png");
            }
            return;
        }

        GameObject visibleNovel = GetPrivate<GameObject>(director, "novelPanel");
        if (director.ActiveSceneId != lastCapturedScene && RequiresSettledNovelCapture(director.ActiveSceneId) &&
            visibleNovel != null && visibleNovel.activeInHierarchy &&
            !GetPrivateValue<bool>(director, "sceneTransitionInProgress") &&
            !GetPrivateValue<bool>(director, "isTyping"))
        {
            lastCapturedScene = director.ActiveSceneId;
            Capture($"scene-{Safe(director.ActiveSceneId)}.png");
        }

        GameObject narration = GameObject.Find("Narration Dialogue");
        if (narration != null && narration.activeInHierarchy)
        {
            FindActiveButton("Narration Continue Button")?.onClick.Invoke();
            nextActionAt = EditorApplication.timeSinceStartup + UiSettleDelay;
            return;
        }

        ScenarioV3Line pendingOutgoing = GetPrivate<ScenarioV3Line>(director, "pendingOutgoingLine");
        if (pendingOutgoing != null)
        {
            if (apps.CurrentAppType != AppType.Message)
            {
                OpenAppImmediate(apps, AppType.Message);
            }
            else
            {
                DialogueManager pendingDialogue = GetPrivate<DialogueManager>(director, "dialogue");
                FieldInfo speakerField = typeof(ScenarioV3Director).GetField("pendingOutgoingSpeaker",
                    BindingFlags.Instance | BindingFlags.NonPublic);
                if (pendingDialogue != null && speakerField != null)
                    pendingDialogue.DismissEventChoices((SpeakerType)speakerField.GetValue(director));
                director.ConfirmPendingOutgoingMessage(pendingOutgoing.id);
                replyBubbleVerified = true;
            }
            nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
            return;
        }

        IReadOnlyList<ScenarioV3Choice> choices = director.CurrentChoices;
        if (choices.Count > 0)
        {
            bool currentChoiceAlreadySubmitted = director.ChoiceHistory.Any(record =>
                record.sceneId == director.ActiveSceneId && record.lineId == director.ActiveLineId);
            if (currentChoiceAlreadySubmitted && apps.CurrentAppType == AppType.Message)
            {
                apps.CloseCurrentApp();
                nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
                return;
            }
            ScenarioV3Choice selected = SelectChoice(director, choices);
            Button visible = FindButtonWithText(selected.text);
            DialogueManager activeDialogue = GetPrivate<DialogueManager>(director, "dialogue");
            if (visible == null && apps.CurrentAppType == AppType.Message && !capturedChoiceDebug &&
                activeDialogue != null && activeDialogue.dialoguePanel != null && activeDialogue.dialoguePanel.activeInHierarchy)
            {
                capturedChoiceDebug = true;
                Dictionary<SpeakerType, ChatChannel> channels = GetPrivate<Dictionary<SpeakerType, ChatChannel>>(activeDialogue, "channels");
                ChatChannel friend = channels != null && channels.TryGetValue(SpeakerType.Friend, out ChatChannel found) ? found : null;
                string buttons = string.Join(" | ", UnityEngine.Object.FindObjectsByType<Button>(FindObjectsInactive.Include)
                    .Where(button => button.gameObject.activeInHierarchy)
                    .Select(button => $"{button.gameObject.name}='{button.GetComponentInChildren<TMP_Text>()?.text}'({button.interactable})"));
                Debug.Log($"[SCENARIO V4 CHOICE DEBUG] wanted='{selected.text}' panel={activeDialogue.dialoguePanel.activeInHierarchy} " +
                          $"events={friend?.eventChoices.Count} pending={friend?.pendingChoiceSets.Count} messages={friend?.receivedMessages.Count} " +
                          $"rendered={friend?.renderedReceivedCount} choiceChildren={activeDialogue.choiceButtonContainer.childCount} buttons={buttons}");
                Capture("choice-debug.png");
            }
            if (visible == null)
            {
                GameObject novel = GetPrivate<GameObject>(director, "novelPanel");
                if (novel != null && novel.activeInHierarchy)
                {
                    GetPrivate<Button>(director, "continueButton")?.onClick.Invoke();
                }
                else
                {
                    if (apps.CurrentAppType != AppType.Message)
                    {
                        OpenAppImmediate(apps, AppType.Message);
                        nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
                        return;
                    }
                    DialogueManager dialogue = GetPrivate<DialogueManager>(director, "dialogue");
                    if (dialogue != null)
                    {
                        FieldInfo waitingSpeaker = typeof(ScenarioV3Director).GetField("waitingMessageSpeaker",
                            BindingFlags.Instance | BindingFlags.NonPublic);
                        SpeakerType speaker = waitingSpeaker != null
                            ? (SpeakerType)waitingSpeaker.GetValue(director)
                            : SpeakerType.Friend;
                        dialogue.OpenDialogue(speaker);
                    }
                }
                nextActionAt = EditorApplication.timeSinceStartup + UiSettleDelay;
                return;
            }

            if (selected.id == "g3_chase")
                expectedConsecutiveGambleScene = "gamble_4";
            else if (selected.id == "g4_continue")
                expectedConsecutiveGambleScene = "gamble_5";
            visible.onClick.Invoke();
            choiceSubmittedAt = EditorApplication.timeSinceStartup;
            if (!string.IsNullOrWhiteSpace(selected.replyText) && VisibleTextContains(selected.replyText))
                replyBubbleVerified = true;
            nextActionAt = EditorApplication.timeSinceStartup + ChoiceSettleDelay;
            return;
        }


        if (director.HasPendingMessageAction && apps.CurrentAppType != AppType.Message)
        {
            OpenAppImmediate(apps, AppType.Message);
            nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
            return;
        }

        if (apps.CurrentAppType == AppType.Message)
        {
            if (director.HasPendingMessageAction)
            {
                nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
                return;
            }

            apps.CloseCurrentApp();
            nextActionAt = EditorApplication.timeSinceStartup + UiSettleDelay;
            return;
        }

        GameObject novelPanel = GetPrivate<GameObject>(director, "novelPanel");
        if (novelPanel != null && novelPanel.activeInHierarchy)
        {
            GetPrivate<Button>(director, "continueButton")?.onClick.Invoke();
            nextActionAt = EditorApplication.timeSinceStartup + UiSettleDelay;
        }
    }

    private static ScenarioV3Choice SelectChoice(ScenarioV3Director director,
        IReadOnlyList<ScenarioV3Choice> choices)
    {
        string[] recoveryChoices =
        {
            "g3_chase", "g4_continue", "g5_borrow", "borrow_mom", "d13_tell_teacher"
        };
        string[] preventionChoices =
        {
            "g3_stop", "g4_stop", "g5_stop"
        };
        string[] noGambleChoices =
        {
            "g3_stop", "g4_stop", "g5_stop"
        };
        string[] noFundsChoices =
        {
            "g3_chase", "g4_continue", "g5_stop", "minjae_loan_reject"
        };
        string[] noHelpChoices =
        {
            "g3_chase", "g4_continue", "g5_stop", "d13_hide_again"
        };
        string[] minjaeDebtChoices =
        {
            "g3_chase", "g4_continue", "g5_stop", "minjae_loan_accept", "d13_tell_teacher"
        };
        string[] seojunDebtChoices =
        {
            "g3_chase", "g4_continue", "g5_borrow", "borrow_friend", "borrow_morning_seojun",
            "d13_tell_teacher"
        };
        string[] loanHeldChoices =
        {
            "g3_chase", "g4_continue", "g5_borrow", "borrow_friend", "borrow_morning_seojun",
            "d13_tell_teacher"
        };
        string[] repeatLossChoices =
        {
            "g3_chase", "g4_continue", "g5_borrow", "borrow_mom", "borrow_morning_mom",
            "borrow_friend", "borrow_morning_seojun", "borrow_minjae", "borrow_morning_minjae",
            "d13_tell_teacher"
        };
        string[] projectFailChoices =
        {
            "g3_stop", "d13_tell_teacher"
        };
        if (route == Route.MixedA || route == Route.MixedB || route == Route.MixedC)
        {
            int salt = route == Route.MixedA ? 17 : route == Route.MixedB ? 43 : 79;
            int hash = salt;
            foreach (ScenarioV3Choice choice in choices)
            {
                foreach (char character in choice.id ?? string.Empty)
                    hash = unchecked(hash * 31 + character);
            }
            return choices[(hash & int.MaxValue) % choices.Count];
        }

        string[] preferred = route == Route.NoGamble || route == Route.Collapse
            ? noGambleChoices
            : route == Route.Prevention
            ? preventionChoices
            : route == Route.NoHelp
                ? noHelpChoices
            : route == Route.NoFunds
                ? noFundsChoices
                : route == Route.MinjaeDebt
                    ? minjaeDebtChoices
                    : route == Route.SeojunDebt
                        ? seojunDebtChoices
                        : route == Route.LoanHeld
                            ? loanHeldChoices
                            : route == Route.RepeatLoss
                                ? repeatLossChoices
                                : route == Route.ProjectFail ? projectFailChoices : recoveryChoices;
        foreach (string id in preferred)
        {
            ScenarioV3Choice match = choices.FirstOrDefault(choice =>
                choice.id == id && IsBorrowChoiceAvailable(director, choice.id));
            if (match != null)
                return match;
        }
        return choices.First(choice => IsBorrowChoiceAvailable(director, choice.id));
    }

    private static bool IsBorrowChoiceAvailable(ScenarioV3Director director, string choiceId)
    {
        if (choiceId is "borrow_mom" or "borrow_morning_mom")
            return director.GetState("borrowed.mom") != "true";
        if (choiceId is "borrow_friend" or "borrow_morning_seojun")
            return director.GetState("borrowed.seojun") != "true";
        if (choiceId is "borrow_minjae" or "borrow_morning_minjae" or "minjae_loan_accept")
            return director.GetState("borrowed.minjae") != "true";
        return true;
    }

    private static bool ShouldStartGamble(ScenarioV3Director director, int day)
    {
        if (string.Equals(director.GetState("pending.borrow_menu"), "true", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(director.GetState("flag.borrow_deferred"), "true", StringComparison.OrdinalIgnoreCase))
            return false;

        if (!director.IsGamblingAppUnlocked || GameFlowManager.Instance == null ||
            !GameFlowManager.Instance.IsDailyScheduleComplete)
            return false;

        int sessions = int.TryParse(director.GetState("counter.gamble_sessions"), out int parsed) ? parsed : 0;
        int target = route switch
        {
            Route.Recovery or Route.MinjaeDebt or Route.SeojunDebt => day >= 3 ? 6 : day == 2 ? 2 : 1,
            Route.LoanHeld => day >= 3 ? 5 : day == 2 ? 2 : 1,
            // Start the binge after day one's required school and study tasks. This reaches the
            // fixed late-round outcomes through normal launcher clicks within the five-day story.
            Route.RepeatLoss => 9,
            Route.ProjectFail => day >= 3 ? 3 : day == 2 ? 2 : 1,
            Route.Prevention => day >= 2 ? 2 : 1,
            Route.NoGamble => 0,
            Route.Collapse => 0,
            Route.NoHelp => day >= 3 ? 3 : day == 2 ? 2 : 1,
            Route.NoFunds => day >= 3 ? 6 : day == 2 ? 2 : 1,
            Route.MixedA => day >= 4 ? 3 : day >= 2 ? 1 : 0,
            Route.MixedB => day >= 4 ? 3 : day >= 3 ? 2 : 0,
            Route.MixedC => day >= 4 ? 5 : day >= 3 ? 4 : day >= 2 ? 2 : 1,
            _ => 0
        };

        if (route == Route.NoFunds && int.TryParse(director.GetState("counter.no_funds_attempts"), out int attempts) && attempts > 0)
            return false;
        return sessions < target;
    }

    private static void BeginMapAction(AppWindow apps, string target)
    {
        apps.CloseCurrentApp();
        apps.OpenMap();
        pendingMapTarget = target;
        nextActionAt = EditorApplication.timeSinceStartup + UiSettleDelay;
    }

    private static void CompleteMapAction()
    {
        string target = pendingMapTarget;
        Button button = FindMapButton(target);
        if (button == null)
        {
            Fail($"Map destination button missing: {target}.");
            return;
        }
        pendingMapTarget = string.Empty;
        GameFlowManager.Instance.TravelTo(target);
        nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
    }

    private static void HandleQuiz(GameFlowManager flow, AppWindow apps)
    {
        if (flow.IsHomeworkDone)
        {
            apps.CloseCurrentApp();
            quizOpen = false;
            nextActionAt = EditorApplication.timeSinceStartup + UiSettleDelay;
            return;
        }

        if (apps.CurrentAppType != AppType.Study)
        {
            apps.OpenStudy();
            nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
            return;
        }

        QuizManager quiz = UnityEngine.Object.FindAnyObjectByType<QuizManager>(FindObjectsInactive.Include);
        Button[] answers = GetPrivate<Button[]>(quiz, "answerButtons");
        List<Button> available = answers?.Where(button => button.gameObject.activeInHierarchy && button.interactable).ToList();
        if (available == null || available.Count == 0)
            return;

        if (capturedQuizDays.Add(flow.CurrentDay))
            Capture($"quiz-day-{flow.CurrentDay:00}.png");

        List<StudyActivityQuestion> questions = GetPrivate<List<StudyActivityQuestion>>(quiz, "currentQuestions");
        int questionIndex = GetPrivateValue<int>(quiz, "currentIndex");
        StudyActivityQuestion currentQuestion = questions != null && questionIndex >= 0 && questionIndex < questions.Count
            ? questions[questionIndex]
            : null;
        Button correct = currentQuestion != null && currentQuestion.answerIndex >= 0 &&
                         currentQuestion.answerIndex < answers.Length
            ? answers[currentQuestion.answerIndex]
            : null;
        if (correct == null || !correct.gameObject.activeInHierarchy || !correct.interactable)
        {
            Fail($"Correct quiz answer was not available on day {flow.CurrentDay}, question {questionIndex + 1}.");
            return;
        }
        correct.onClick.Invoke();
        nextActionAt = EditorApplication.timeSinceStartup + SceneSettleDelay;
    }

    private static bool ShouldCaptureScene(string scene)
    {
        return scene is "gamble_1" or "gamble_3" or "gamble_5" or "borrow_choice" or
               "v5_d4_school_risk" or "v5_d4_help_response" or "v5_d4_hide_result" or
               "v5_d2_missed_daytime" or "v5_d3_missed_daytime_first" or
               "v5_d3_missed_daytime_fired" or "ending_recovery" or "ending_prevented" or
               "ending_no_help" or "collapse_check_stable" or "collapse_check_gamble" or
               "collapse_check_debt";
    }

    private static bool RequiresSettledNovelCapture(string scene)
    {
        return scene is "v5_d2_missed_daytime" or "v5_d3_missed_daytime_first" or
               "v5_d3_missed_daytime_fired";
    }

    private static Button FindMapButton(string displayName)
    {
        MapLocationController map = UnityEngine.Object.FindAnyObjectByType<MapLocationController>(FindObjectsInactive.Include);
        Array locations = GetPrivate<Array>(map, "locations");
        if (locations == null)
            return null;
        string code = displayName == "학교" ? "1" : displayName == "카페" ? "2" : "3";
        foreach (object location in locations)
        {
            FieldInfo nameField = location.GetType().GetField("locationName");
            FieldInfo buttonField = location.GetType().GetField("button");
            if ((string)nameField?.GetValue(location) == code)
                return buttonField?.GetValue(location) as Button;
        }
        return null;
    }

    private static Button FindActiveButton(string name) =>
        UnityEngine.Object.FindObjectsByType<Button>(FindObjectsInactive.Include)
            .FirstOrDefault(button => button.gameObject.activeInHierarchy && button.gameObject.name == name);

    private static Button FindButtonWithText(string text) =>
        UnityEngine.Object.FindObjectsByType<Button>(FindObjectsInactive.Include)
            .FirstOrDefault(button => button.gameObject.activeInHierarchy && button.interactable &&
                                      button.GetComponentInChildren<TMP_Text>()?.text == text);

    private static bool VisibleTextContains(string text) =>
        UnityEngine.Object.FindObjectsByType<TMP_Text>(FindObjectsInactive.Include)
            .Any(label => label != null && label.gameObject != null && label.gameObject.activeInHierarchy &&
                          !string.IsNullOrEmpty(label.text) && label.text.Contains(text));

    private static T GetPrivate<T>(object target, string fieldName) where T : class
    {
        return target?.GetType().GetField(fieldName, BindingFlags.Instance | BindingFlags.NonPublic)
            ?.GetValue(target) as T;
    }

    private static T GetPrivateValue<T>(object target, string fieldName) where T : struct
    {
        object value = target?.GetType().GetField(fieldName, BindingFlags.Instance | BindingFlags.NonPublic)
            ?.GetValue(target);
        return value is T typed ? typed : default;
    }

    private static void InvokePrivate(object target, string methodName)
    {
        target?.GetType().GetMethod(methodName, BindingFlags.Instance | BindingFlags.NonPublic)
            ?.Invoke(target, null);
    }

    private static void OpenAppImmediate(AppWindow apps, AppType type)
    {
        apps.OpenApp(type);
        typeof(AppWindow).GetMethod("ActivateApp", BindingFlags.Instance | BindingFlags.NonPublic)
            ?.Invoke(apps, new object[] { type });
    }

    private static void DismissNarration(GameFlowManager flow)
    {
        InvokePrivate(flow, "CloseNarration");
        InvokePrivate(flow, "CloseNarration");
    }

    private static void ExpectWeekendScheduleScenes(string suffix)
    {
        string[] expected =
        {
            $"v5_d2_study_cue_{suffix}",
            "v5_d2_study_done",
            $"v5_d2_night_{suffix}",
            $"v5_d3_case_cue_{suffix}",
            "v5_d3_study_done",
            $"v5_d3_night_{suffix}"
        };
        foreach (string scene in expected)
            Expect(observedScenes.Contains(scene), $"Weekend schedule scene was not played: {scene}.");
        if (suffix == "missed")
        {
            Expect(observedScenes.Contains("v5_d2_minjae_after_miss"),
                "Minjae's day-2 follow-up after the missed job was not played.");
            Expect(observedScenes.Contains("v5_d2_missed_daytime"),
                "The day-2 missed-job daytime bridge was not played.");
            Expect(observedScenes.Contains("v5_d3_minjae_after_miss"),
                "Minjae's day-3 follow-up after the missed job was not played.");
            Expect(observedScenes.Contains("v5_d3_missed_daytime_fired"),
                "The consecutive-miss daytime bridge was not played.");
        }
    }

    private static void Expect(bool condition, string message)
    {
        if (!condition)
            Fail(message);
    }

    private static void Fail(string message)
    {
        if (!failed)
            Debug.LogError($"[SCENARIO V4 {route.ToString().ToUpperInvariant()} QA] {message}");
        failed = true;
    }

    private static string Safe(string value)
    {
        foreach (char invalid in Path.GetInvalidFileNameChars())
            value = value.Replace(invalid, '_');
        return value;
    }

    private static void Capture(string filename)
    {
        if (SystemInfo.graphicsDeviceType == UnityEngine.Rendering.GraphicsDeviceType.Null)
            return;

        string directory = Path.GetFullPath(Path.Combine(Application.dataPath,
            $"../Logs/ScenarioV4FullQa/{route}"));
        Directory.CreateDirectory(directory);
        string path = Path.Combine(directory, filename);
        Camera camera = Camera.main ?? UnityEngine.Object.FindAnyObjectByType<Camera>();
        Canvas canvas = UnityEngine.Object.FindObjectsByType<Canvas>(FindObjectsInactive.Include)
            .FirstOrDefault(candidate => candidate.gameObject.activeInHierarchy && candidate.transform.parent == null);
        if (camera == null || canvas == null)
        {
            Fail("Camera or root canvas missing while capturing.");
            return;
        }

        const int width = 1600;
        const int height = 900;
        RenderMode oldMode = canvas.renderMode;
        Camera oldCanvasCamera = canvas.worldCamera;
        RenderTexture oldTarget = camera.targetTexture;
        RenderTexture oldActive = RenderTexture.active;
        RenderTexture target = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32);
        Texture2D texture = new Texture2D(width, height, TextureFormat.RGB24, false);
        try
        {
            canvas.renderMode = RenderMode.ScreenSpaceCamera;
            canvas.worldCamera = camera;
            canvas.planeDistance = 1f;
            camera.targetTexture = target;
            camera.Render();
            RenderTexture.active = target;
            texture.ReadPixels(new Rect(0, 0, width, height), 0, 0);
            texture.Apply();
            File.WriteAllBytes(path, texture.EncodeToPNG());
        }
        finally
        {
            camera.targetTexture = oldTarget;
            RenderTexture.active = oldActive;
            canvas.renderMode = oldMode;
            canvas.worldCamera = oldCanvasCamera;
            UnityEngine.Object.DestroyImmediate(texture);
            target.Release();
            UnityEngine.Object.DestroyImmediate(target);
        }
    }
}
#endif
