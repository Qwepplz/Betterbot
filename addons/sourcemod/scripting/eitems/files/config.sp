public void LoadConfig()
{
    if (!FileExists(g_szConfigFilePath))
    {
        SetFailState("%s Unable to find config file: %s", TAG_NCLR, g_szConfigFilePath);
        return;
    }

    JSONObject jRoot = JSONObject.FromFile(g_szConfigFilePath);
    if (jRoot == null)
    {
        SetFailState("%s Unable to parse config file: %s", TAG_NCLR, g_szConfigFilePath);
        return;
    }

    if (!jRoot.GetString("Language", g_szLanguageCode, sizeof g_szLanguageCode)
        || (!StrEqual(g_szLanguageCode, "en", true) && !StrEqual(g_szLanguageCode, "zh_hans", true)))
    {
        delete jRoot;
        SetFailState("%s Invalid language in config file: %s. Allowed values: en, zh_hans", TAG_NCLR, g_szConfigFilePath);
        return;
    }

    g_bForceDisableHibernation = jRoot.GetBool("ForceDisableHibernation");
    delete jRoot;
}
