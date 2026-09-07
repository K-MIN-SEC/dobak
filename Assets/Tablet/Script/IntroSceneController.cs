using System.Collections;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public sealed class IntroSceneController : MonoBehaviour
{
    [SerializeField] private CanvasGroup content;
    [SerializeField] private Button startButton;
    private AsyncOperation preloadedScene;

    private void Awake()
    {
        UIFontProvider.ApplyToAllText();
        ConfigureTitlePresentation();

        if (content != null)
            content.alpha = 0f;
        if (startButton != null)
        {
            startButton.onClick.RemoveListener(StartGame);
            startButton.onClick.AddListener(StartGame);
        }
    }

    private void ConfigureTitlePresentation()
    {
        Image background = GameObject.Find("Bedroom Illustration")?.GetComponent<Image>();
        Sprite titleBackground = Resources.Load<Sprite>("TitleArt/TitleBackground");
        if (background != null && titleBackground != null)
        {
            background.sprite = titleBackground;
            background.preserveAspect = false;
        }

        if (content == null)
            return;

        TMP_Text title = content.transform.Find("Intro Title")?.GetComponent<TMP_Text>();
        if (title != null)
        {
            TMP_FontAsset font = UIFontProvider.Get();
            if (font != null)
                title.font = font;
            title.text = "할래말래";
            title.fontSize = 112f;
            title.alignment = TextAlignmentOptions.Center;
            Outline outline = title.GetComponent<Outline>() ?? title.gameObject.AddComponent<Outline>();
            outline.effectColor = new Color(0.005f, 0.01f, 0.02f, 0.88f);
            outline.effectDistance = new Vector2(4f, -4f);
        }

        CreateAccent("Title Accent", new Vector2(0f, 0.5f), new Vector2(0f, 16f),
            new Vector2(470f, 4f), new Color(0.72f, 0.13f, 0.17f, 0.95f));
        CreateCredit("Jungnang Police Credit", "중랑경찰서",
            new Vector2(0.5f, 0f), new Vector2(0f, 48f), new Vector2(420f, 44f));
    }

    private void CreateAccent(string name, Vector2 anchor, Vector2 position, Vector2 size, Color color)
    {
        if (content.transform.Find(name) != null)
            return;

        GameObject accent = new GameObject(name, typeof(RectTransform), typeof(CanvasRenderer), typeof(Image));
        accent.transform.SetParent(content.transform, false);
        Image image = accent.GetComponent<Image>();
        image.color = color;
        image.raycastTarget = false;

        RectTransform rect = accent.GetComponent<RectTransform>();
        rect.anchorMin = rect.anchorMax = anchor;
        rect.pivot = new Vector2(0.5f, 0.5f);
        rect.anchoredPosition = position;
        rect.sizeDelta = size;
    }

    private void CreateCredit(string name, string value, Vector2 anchor, Vector2 position, Vector2 size)
    {
        if (content.transform.Find(name) != null)
            return;

        TMP_Text source = content.transform.Find("Intro Title")?.GetComponent<TMP_Text>();
        if (source == null)
            return;

        GameObject credit = new GameObject(name, typeof(RectTransform), typeof(CanvasRenderer), typeof(TextMeshProUGUI));
        credit.transform.SetParent(content.transform, false);
        TMP_Text text = credit.GetComponent<TMP_Text>();
        text.font = source.font;
        text.fontSize = 34f;
        text.fontStyle = FontStyles.Bold;
        text.alignment = TextAlignmentOptions.Center;
        text.color = new Color(0.92f, 0.95f, 1f, 0.92f);
        text.text = value;
        text.raycastTarget = false;

        RectTransform rect = text.rectTransform;
        rect.anchorMin = rect.anchorMax = anchor;
        rect.pivot = new Vector2(0.5f, 0.5f);
        rect.anchoredPosition = position;
        rect.sizeDelta = size;
    }

    private IEnumerator Start()
    {
        preloadedScene = SceneManager.LoadSceneAsync("TabletUI", LoadSceneMode.Single);
        if (preloadedScene != null)
            preloadedScene.allowSceneActivation = false;
        yield return null;
    }

    private void Update()
    {
        if (content != null && content.alpha < 1f)
            content.alpha = Mathf.MoveTowards(content.alpha, 1f, Time.unscaledDeltaTime * 1.8f);
    }

    private void OnDestroy()
    {
        if (startButton != null)
            startButton.onClick.RemoveListener(StartGame);
    }

    public void StartGame()
    {
        if (startButton != null)
            startButton.interactable = false;

        // TabletUI가 먼저 한 프레임 노출되는 것을 막고, 첫 VN이 준비된 뒤에만 커튼을 걷는다.
        ScenarioV3TransitionCurtain.CoverUntilFirstStory();

        if (preloadedScene != null)
            preloadedScene.allowSceneActivation = true;
        else
            SceneManager.LoadScene("TabletUI");
    }
}
