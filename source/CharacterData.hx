package;

class CharacterData
{
    public var id:String;
    public var name:String;
    public var folder:String;
    public var iconAsset:String;
    public var sheetAsset:String;
    public var xmlAsset:String;
    public var scale:Float;

    public function new(folder:String, name:String, scale:Float = 1.0)
    {
        this.folder = folder;
        this.id = folder;
        this.name = name;
        this.scale = scale;
        iconAsset = folder + "/Icon.png";
        sheetAsset = folder + "/CharacterAnimation.png";
        xmlAsset = folder + "/CharacterAnimation.xml";
    }
}
