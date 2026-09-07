using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.TextCore.LowLevel;

public static class UIFontProvider
{
    private const string SourceFontPath = "Fonts/PretendardVariable";

    private static TMP_FontAsset primaryFont;

    public static TMP_FontAsset Get()
    {
        if (primaryFont != null)
            return primaryFont;

        Font source = Resources.Load<Font>(SourceFontPath);
        if (source == null)
            return FindKoreanFallback();

        primaryFont = TMP_FontAsset.CreateFontAsset(
            source,
            90,
            8,
            GlyphRenderMode.SDFAA,
            2048,
            2048,
            AtlasPopulationMode.Dynamic,
            true);

        if (primaryFont == null)
            return FindKoreanFallback();

        TMP_FontAsset koreanFallback = FindKoreanFallback();
        if (koreanFallback != null && koreanFallback != primaryFont)
            primaryFont.fallbackFontAssetTable = new List<TMP_FontAsset> { koreanFallback };

        return primaryFont;
    }

    public static void ApplyToAllText()
    {
        TMP_FontAsset font = Get();
        if (font == null)
            return;

        foreach (TMP_Text text in Resources.FindObjectsOfTypeAll<TMP_Text>())
        {
            if (text != null && text.gameObject.scene.IsValid())
                text.font = font;
        }
    }

    private static TMP_FontAsset FindKoreanFallback()
    {
        TMP_FontAsset firstAvailable = null;
        foreach (TMP_FontAsset candidate in Resources.FindObjectsOfTypeAll<TMP_FontAsset>())
        {
            if (candidate == null)
                continue;

            firstAvailable ??= candidate;
            if (candidate.name.Contains("NotoSansKR"))
                return candidate;
        }

        return firstAvailable;
    }
}
