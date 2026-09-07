using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
using UnityEngine.UI;

public static class IntroSceneBuilder
{
    private const string IntroScenePath = "Assets/Tablet/Intro.unity";
    private const string TabletScenePath = "Assets/Tablet/TabletUI.unity";

    public static void Build()
    {
        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        TMP_FontAsset font = AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(
            "Assets/Tablet/Front/NotoSansKR-Regular SDF.asset");
        Sprite background = AssetDatabase.LoadAssetAtPath<Sprite>(
            "Assets/Resources/ScenarioArt/bedroom_night.png");

        GameObject cameraObject = new GameObject("Main Camera", typeof(Camera), typeof(AudioListener));
        cameraObject.tag = "MainCamera";
        Camera camera = cameraObject.GetComponent<Camera>();
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(0.025f, 0.045f, 0.075f);

        GameObject eventSystem = new GameObject("EventSystem", typeof(EventSystem), typeof(InputSystemUIInputModule));
        eventSystem.GetComponent<InputSystemUIInputModule>().AssignDefaultActions();

        GameObject canvasObject = new GameObject("Intro Canvas", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
        Canvas canvas = canvasObject.GetComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        CanvasScaler scaler = canvasObject.GetComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1920f, 1080f);
        scaler.matchWidthOrHeight = 0.5f;

        Image backgroundImage = Image("Bedroom Illustration", canvas.transform, Color.white);
        backgroundImage.sprite = background;
        backgroundImage.preserveAspect = false;
        Stretch(backgroundImage.rectTransform);
        Image dim = Image("Intro Dim", canvas.transform, new Color(0.01f, 0.015f, 0.025f, 0.42f));
        Stretch(dim.rectTransform);

        GameObject contentObject = new GameObject("Intro Content", typeof(RectTransform), typeof(CanvasGroup));
        contentObject.transform.SetParent(canvas.transform, false);
        RectTransform contentRect = contentObject.GetComponent<RectTransform>();
        contentRect.anchorMin = Vector2.zero;
        contentRect.anchorMax = Vector2.one;
        contentRect.offsetMin = contentRect.offsetMax = Vector2.zero;
        CanvasGroup content = contentObject.GetComponent<CanvasGroup>();

        TMP_Text title = Text("Intro Title", contentObject.transform, font, "할래말래", 112, FontStyles.Bold);
        title.color = Color.white;
        title.alignment = TextAlignmentOptions.Center;
        SetCenteredRect(title.rectTransform, new Vector2(0f, 120f), new Vector2(920f, 170f));

        Button startButton = Button("Start Game", contentObject.transform, font, "게임하기");
        RectTransform buttonRect = startButton.GetComponent<RectTransform>();
        SetCenteredRect(buttonRect, new Vector2(0f, -78f), new Vector2(340f, 78f));

        GameObject controllerObject = new GameObject("Intro Scene Controller");
        IntroSceneController controller = controllerObject.AddComponent<IntroSceneController>();
        SerializedObject serialized = new SerializedObject(controller);
        serialized.FindProperty("content").objectReferenceValue = content;
        serialized.FindProperty("startButton").objectReferenceValue = startButton;
        serialized.ApplyModifiedPropertiesWithoutUndo();

        EditorSceneManager.SaveScene(scene, IntroScenePath);
        EditorBuildSettings.scenes = new[]
        {
            new EditorBuildSettingsScene(IntroScenePath, true),
            new EditorBuildSettingsScene(TabletScenePath, true)
        };
        AssetDatabase.SaveAssets();
    }

    private static Image Image(string name, Transform parent, Color color)
    {
        GameObject go = new GameObject(name, typeof(RectTransform), typeof(CanvasRenderer), typeof(Image));
        go.transform.SetParent(parent, false);
        Image image = go.GetComponent<Image>();
        image.color = color;
        return image;
    }

    private static TMP_Text Text(string name, Transform parent, TMP_FontAsset font, string value, float size, FontStyles style)
    {
        GameObject go = new GameObject(name, typeof(RectTransform), typeof(CanvasRenderer), typeof(TextMeshProUGUI));
        go.transform.SetParent(parent, false);
        TMP_Text text = go.GetComponent<TMP_Text>();
        text.font = font;
        text.fontSize = size;
        text.fontStyle = style;
        text.text = value;
        text.alignment = TextAlignmentOptions.Left;
        text.textWrappingMode = TextWrappingModes.Normal;
        return text;
    }

    private static Button Button(string name, Transform parent, TMP_FontAsset font, string label)
    {
        GameObject go = new GameObject(name, typeof(RectTransform), typeof(CanvasRenderer), typeof(Image), typeof(Button));
        go.transform.SetParent(parent, false);
        Image image = go.GetComponent<Image>();
        image.color = new Color(0.67f, 0.14f, 0.18f, 0.98f);
        Button button = go.GetComponent<Button>();
        ColorBlock colors = button.colors;
        colors.highlightedColor = new Color(0.8f, 0.2f, 0.24f);
        colors.pressedColor = new Color(0.48f, 0.08f, 0.11f);
        button.colors = colors;
        TMP_Text text = Text("Label", go.transform, font, label, 28, FontStyles.Bold);
        text.alignment = TextAlignmentOptions.Center;
        text.color = Color.white;
        Stretch(text.rectTransform);
        return button;
    }

    private static void Stretch(RectTransform rect)
    {
        rect.anchorMin = Vector2.zero;
        rect.anchorMax = Vector2.one;
        rect.offsetMin = rect.offsetMax = Vector2.zero;
    }

    private static void SetRect(RectTransform rect, Vector2 position, Vector2 size)
    {
        rect.anchorMin = rect.anchorMax = Vector2.zero;
        rect.pivot = Vector2.zero;
        rect.anchoredPosition = position;
        rect.sizeDelta = size;
    }

    private static void SetCenteredRect(RectTransform rect, Vector2 position, Vector2 size)
    {
        rect.anchorMin = rect.anchorMax = new Vector2(0.5f, 0.5f);
        rect.pivot = new Vector2(0.5f, 0.5f);
        rect.anchoredPosition = position;
        rect.sizeDelta = size;
    }
}
