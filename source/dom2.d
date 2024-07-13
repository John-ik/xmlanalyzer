module dom2;

struct DOMEntity2 (R)
{


private:

    auto _type = EntityType.elementStart;
    TextPos _pos;
    SliceOfR _name;
    SliceOfR[] _path;
    Attribute[] _attributes;
    SliceOfR _text;
    DOMEntity[] _children;

    
}