package;

/**
 * Configuracao central dos anuncios do TorajoRP.
 * Edite este arquivo para configurar o AdMob.
 */
class AdsConfig
{
    /** Ativa ou desativa todos os anuncios do jogo. */
    public static inline var ENABLE_ADS:Bool = false;

    /**
     * Indicador para organização do projeto. Na extension-admob 3.0.1,
     * TEST_MODE nao e enviado a Admob.init(): o tipo de anuncio depende
     * dos IDs configurados abaixo. Use IDs oficiais de teste durante
     * o desenvolvimento e troque por IDs reais somente na publicacao.
     */
    public static inline var TEST_MODE:Bool = false;

    // IDs oficiais de teste do Google para Android.
    // Substitua pelos IDs das unidades do seu app quando for publicar.
    public static inline var BANNER_AD_UNIT_ID:String = "SeuID";
    public static inline var INTERSTITIAL_AD_UNIT_ID:String = "SeuID";
    public static inline var REWARDED_AD_UNIT_ID:String = "SeuID";
}
