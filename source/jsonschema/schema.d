module jsonschema.schema;

import std.sumtype, std.exception, std.conv, std.format, std.typecons, std.regex, jsonschema.constraints, std.algorithm;

enum JsonSchemaType
{
    failsafe,
    string_     = 1 << 0,
    number      = 1 << 1,
    object      = 1 << 2,
    array       = 1 << 3,
    boolean     = 1 << 4,
    null_       = 1 << 5,
    integer     = 1 << 6,
    _enum,
    _blanket
}

struct SchemaGroup(Things_...)
{
    alias Things = Things_;
}

struct JsonSchema(
    Adapter_,
    ConstraintGroup
)
{
    alias Adapter    = Adapter_;
    alias ObjectType = Adapter.ObjectType;
    alias ArrayType  = Adapter.ArrayType;
    alias ValueType  = Adapter.ValueType;
    alias CGroup     = ConstraintGroup;
    alias Constraint = SumType!(ConstraintGroup.Things);

    static struct Item
    {
        // common
        JsonSchemaType      types;
        Constraint[]        constraints;
        ValueType[string]   unhandled;

        // annotations
        string              title;
        string              description;

        // blankets
        bool                allowOrDenyAll;

        // objects
        Property[string]    properties;
        Property[]          patternProperties;
        Item[]              additionalProperties; // Stored as an array to avoid forward referencing, but should be treated as an Item[1]
        Regex!char          propertyNames;
        string[]            requiredProperties;

        // enums
        ValueType[]         enumValues;

        // arrays
        Item[]              itemType;       // list validation. Array used as a single value.
        Item[]              prefixItems;    // Tuple validation
    }

    static struct Property
    {
        string name;
        Item item;
    }

    private
    {
        Item _root;
    }

    void parseSchema(ValueType root)
    {
        const rootType = Adapter.getType(root);
        if(rootType == JsonSchemaType.object)
            this._root = this.parseItem(root);
        else
            throw new Exception("Only objects as the root are supported for now, not: "~rootType.to!string);
    }

    private
    {
        Item parseItem(ValueType itemValue)
        {
            Item item;

            const vType = Adapter.getType(itemValue);
            if(vType == JsonSchemaType.boolean)
            {
                item.types = JsonSchemaType._blanket;
                item.allowOrDenyAll = Adapter.getBoolean(itemValue);
                return item;
            }
            else if(vType != JsonSchemaType.object)
                throw new Exception("Expected value to be an object or a boolean, not: "~vType.to!string);

            auto obj = Adapter.getObject(itemValue);
            Adapter.objectEach(obj, (objKey, value)
            {
                Switch: switch(objKey)
                {
                    case "type":
                        const typeType = Adapter.getType(value);
                        if(typeType == JsonSchemaType.array)
                        {
                            Adapter.arrayEach(Adapter.getArray(value), (i, v) {
                                enforce(Adapter.getType(v) == JsonSchemaType.string_, "Expected value #%s in 'type' array to be a string, not: %s".format(
                                    i, Adapter.getType(v)
                                ));
                                item.types |= typeStringToType(Adapter.getString(v));
                            });
                        }
                        else if(typeType == JsonSchemaType.string_)
                            item.types = this.typeStringToType(Adapter.getString(value));
                        else
                            throw new Exception("Expected property 'type' to be a string or an array, not: "~typeType.to!string);
                        break;

                    case "description":
                        enforce(Adapter.getType(value) == JsonSchemaType.string_, "Expected the 'description' property to be a string.");
                        item.description = Adapter.getString(value);
                        break;

                    case "title":
                        enforce(Adapter.getType(value) == JsonSchemaType.string_, "Expected the 'title' property to be a string.");
                        item.title = Adapter.getString(value);
                        break;

                    case "properties":
                        enforce(Adapter.getType(value) == JsonSchemaType.object, "Expected the 'properties' property to be an object.");
                        Adapter.objectEach(Adapter.getObject(value), (k, v){
                            enforce(Adapter.getType(v) == JsonSchemaType.object, "Expected any subproperty of the 'properties' attribute to contain an object as a value.");
                            item.properties[k] = Property(k, parseItem(v));
                        });
                        break;

                    case "patternProperties":
                        enforce(Adapter.getType(value) == JsonSchemaType.object, "Expected the 'patternProperties' property to be an object.");
                        Adapter.objectEach(Adapter.getObject(value), (k, v){
                            enforce(Adapter.getType(v) == JsonSchemaType.object, "Expected any subproperty of the 'patternProperties' attribute to contain an object as a value.");
                            item.patternProperties ~= Property(k, parseItem(v));
                        });
                        break;

                    case "additionalProperties":
                        item.additionalProperties ~= parseItem(value);
                        break;

                    case "propertyNames":
                        enforce(Adapter.getType(value) == JsonSchemaType.object, "Expected the 'propertyNames' property to be an object.");
                        auto valueAsObj = Adapter.getObject(value);
                        const hasPattern = Adapter.getObjectValue(valueAsObj, "pattern", value);
                        enforce(hasPattern, "Expected the 'propertyNames' property to contain a subproperty named 'pattern'.");
                        item.propertyNames = regex(Adapter.getString(value));
                        break;

                    case "enum":
                        enforce(Adapter.getType(value) == JsonSchemaType.array, "Expected the 'enum' property to be an array.");
                        auto valueAsArray = Adapter.getArray(value);
                        Adapter.arrayEach(valueAsArray, (i, v)
                        {
                            item.enumValues ~= v;
                        });
                        item.types = JsonSchemaType._enum;
                        break;

                    case "items":
                        item.itemType ~= parseItem(value);
                        break;

                    case "prefixItems":
                        enforce(Adapter.getType(value) == JsonSchemaType.array, "Expected the 'prefixItems' property to be an array.");
                        Adapter.arrayEach(Adapter.getArray(value), (i, v)
                        {
                            item.prefixItems ~= parseItem(v);
                        });
                        break;

                    case "required":
                        enforce(Adapter.getType(value) == JsonSchemaType.array, "Expected the 'requiredProperties' property to be an array.");
                        Adapter.arrayEach(Adapter.getArray(value), (i, v)
                        {
                            item.requiredProperties ~= Adapter.getString(v);
                        });
                        break;

                    static foreach(ConstraintT; ConstraintGroup.Things)
                    {
                        case ConstraintT.KEYWORD:
                            ConstraintT c;
                            c.parse!Adapter(value);
                            item.constraints ~= Constraint(c);
                            break Switch;
                    }

                    default:
                        item.unhandled[objKey] = value;
                        break;
                }
            });

            return item;
        }

        JsonSchemaType typeStringToType(string typeString)
        {
            switch(typeString) with(JsonSchemaType)
            {
                case "string": return string_;
                case "number": return number;
                case "object": return object;
                case "array": return array;
                case "boolean": return boolean;
                case "null": return null_;
                case "integer": return integer;
                default:
                    throw new Exception("Unknown type: "~typeString);
            }
        }
    }
}

string[] validate(ValueAdapter, Schema)(const Schema schema, ValueAdapter.ValueType valueRoot)
{
    string[] errors;
    void validateAgainst(const Schema.Item item, ValueAdapter.ValueType v)
    {
        const vType = ValueAdapter.getType(v);

        if(item.types == JsonSchemaType._enum)
        {
            bool foundMatch;
            foreach(enumValue; item.enumValues)
            {
                if(compare!(Schema.Adapter, ValueAdapter)(enumValue, v))
                {
                    foundMatch = true;
                    break;
                }
            }

            if(!foundMatch)
                errors ~= format!"Expected any of: %s"(item.enumValues);

            return;
        }
        else if(item.types == JsonSchemaType._blanket)
        {
            if(!item.allowOrDenyAll)
                errors ~= "Property cannot exist. Matched against a 'false' schema item.";

            return;
        }
        else if((item.types & vType) == 0)
        {
            errors ~= format!"Schema item expects value to be of type '%s', not '%s'."(
                item.types, vType
            );
            return;
        }

        switch(vType) with(JsonSchemaType)
        {
            case object:
                string[] found;
                auto vAsObj = ValueAdapter.getObject(v);
                ValueAdapter.objectEach(vAsObj, (key, value)
                {
                    if(item.propertyNames != Regex!char.init && !matchFirst(key, item.propertyNames))
                    {
                        errors ~= "Key '%s' failed to match against pattern '%s'".format(key, item.propertyNames);
                        return;
                    }

                    const prop = (key in item.properties);
                    found ~= key;
                    if(!prop)
                    {
                        foreach(patternProp; item.patternProperties)
                        {
                            if(matchFirst(key, patternProp.name.regex))
                            {
                                validateAgainst(patternProp.item, value);
                                return;
                            }
                        }

                        if(item.additionalProperties.length)
                            validateAgainst(item.additionalProperties[0], value);
                        return;
                    }

                    validateAgainst(prop.item, value);
                });

                foreach(propName; item.requiredProperties)
                {
                    if(!found.canFind(propName))
                        errors ~= "Required property '%s' was not provided.".format(propName);
                }

                foreach(constraint; item.constraints)
                {
                    constraint.match!(
                        (c)
                        {
                            if(auto error = c.validateObject!ValueAdapter(vAsObj))
                                errors ~= error;
                        }
                    );
                }
                break;

            case array:
                auto vAsArray = ValueAdapter.getArray(v);
                ValueAdapter.arrayEach(vAsArray, (i, value)
                {
                    if(i < item.prefixItems.length)
                        validateAgainst(item.prefixItems[i], value);
                    else if(item.itemType.length)
                        validateAgainst(item.itemType[0], value);
                });

                foreach(constraint; item.constraints)
                {
                    constraint.match!(
                        (c)
                        {
                            if(auto error = c.validateArray!ValueAdapter(vAsArray))
                                errors ~= error;
                        }
                    );
                }
                break;

            case number | integer:
            case integer:
            case number:
            case string_:
                foreach(constraint; item.constraints)
                {
                    constraint.match!(
                        (c)
                        {
                            if(auto error = c.validateValue!ValueAdapter(v))
                                errors ~= error;
                        }
                    );
                }
                break;

            default: throw new Exception("Unhandled: "~v.to!string);
        }
    }

    validateAgainst(schema._root, valueRoot);
    return errors;
}

bool typeCompare(SchemaAdapter, ValueAdapter)(SchemaAdapter.ValueType sv, ValueAdapter.ValueType vv)
{
    auto st = SchemaAdapter.getType(sv);
    auto vt = ValueAdapter.getType(vv);

    if(st == JsonSchemaType.integer)
        st = JsonSchemaType.number;
    if(vt == JsonSchemaType.integer)
        vt = JsonSchemaType.number;

    return st == vt;
}

bool compare(SchemaAdapter, ValueAdapter)(SchemaAdapter.ValueType sv, ValueAdapter.ValueType vv)
{
    if(!typeCompare!(SchemaAdapter, ValueAdapter)(sv, vv))
        return false;
    final switch(SchemaAdapter.getType(sv)) with(JsonSchemaType)
    {
        case _enum:
        case _blanket:
        case failsafe: assert(false);
        case string_: return SchemaAdapter.getString(sv) == ValueAdapter.getString(vv);
        case number: return SchemaAdapter.getNumber(sv) == ValueAdapter.getNumber(vv);
        case integer: return SchemaAdapter.getNumber(sv).to!long == ValueAdapter.getNumber(vv).to!long;
        case object: 
        case array:
            assert(false, "Object and array comparison isn't implemented yet.");
        case boolean: return SchemaAdapter.getBoolean(sv) == ValueAdapter.getBoolean(vv);
        case null_: return true;
    }
}

import jsonschema.adapters;
alias JsonSchemaDefaultConstraints = SchemaGroup!(
    JsonMaxPropertiesConstraint,
    JsonMinPropertiesConstraint,
    JsonMaxItemsConstraint,
    JsonMinItemsConstraint,
    JsonUniqueItemsConstraint,
    JsonPatternConstraint,
    JsonMultipleConstraint
);
alias JsonSchemaStdDefault = JsonSchema!(StdJsonAdapter, JsonSchemaDefaultConstraints);

version(unittest) 
{
    import std.json : parseJSON;
    import sdlite;

    SDLNode parseSdlang(string code)
    {
        SDLNode root;
        parseSDLDocument!(n => root.children ~= n)(code, null);
        return root;
    }
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
        { "type": "object" }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        {
            "key": "value",
            "another_key": "another_value"
        }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
    {
        "Sun": 1.9891e30,
        "Jupiter": 1.8986e27,
        "Saturn": 5.6846e26,
        "Neptune": 10.243e25,
        "Uranus": 8.6810e25,
        "Earth": 5.9736e24,
        "Venus": 4.8685e24,
        "Mars": 6.4185e23,
        "Mercury": 3.3022e23,
        "Moon": 7.349e22,
        "Pluto": 1.25e22
    }
    `)).length == 0);

    assert(validate!SdliteAdapter(schema, parseSdlang(`
        key "value"
        another_key "another_value"
    `)).length == 0);

    assert(validate!SdliteAdapter(schema, parseSdlang(`
        Sun 1.9891
        Jupiter 1.8986
        Saturn 5.6846
        Neptune 10.243
        Uranus 8.6810
        Earth 5.9736
        Venus 4.8685
        Mars 6.4185
        Mercury 3.3022
        Moon 7.349
        Pluto 1.25
    `)).length == 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
    {
        "type": "object",
        "properties": {
            "number": { "type": "number" },
            "street_name": { "type": "string" },
            "street_type": { "enum": ["Street", "Avenue", "Boulevard"] }
        }
    }
    `));

    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "number": 1600, "street_name": "Pennsylvania", "street_type": "Avenue" }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "number": "1600", "street_name": "Pennsylvania", "street_type": "Avenue" }
    `)).length > 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "number": 1600, "street_name": "Pennsylvania" }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "number": 1600, "street_name": "Pennsylvania", "street_type": "Avenue", "direction": "NW" }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "number": 1600, "street_name": "Pennsylvania", "street_type": "Avenueeee" }
    `)).length > 0);

    assert(validate!SdliteAdapter(schema, parseSdlang(`
        number 1600
        street_name "Pennsylvania"
        street_type "Avenue"
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        number "1600"
        street_name "Pennsylvania"
        street_type "Avenue"
    `)).length > 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        number 1600
        street_name "Pennsylvania"
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        number 1600
        street_name "Pennsylvania"
        street_type "Avenue"
        direction "NW"
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        number 1600
        street_name "Pennsylvania"
        street_type "Avenueeee"
    `)).length > 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
    {
        "type": "object",
        "patternProperties": {
            "^S_": { "type": "string" },
            "^I_": { "type": "integer" }
        }
    }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "S_25": "This is a string" }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "I_0": 42 }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "keyword": "value" }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "S_0": 42 }
    `)).length > 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "I_42": "This is a string" }
    `)).length > 0);

    assert(validate!SdliteAdapter(schema, parseSdlang(`
        S_25 "This is a string"
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        I_0 42
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        keyword "value"
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        S_0 42
    `)).length > 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        I_42 "This is a string"
    `)).length > 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
    {
        "type": "object",
        "properties": {
            "number": { "type": "number" },
            "street_name": { "type": "string" },
            "street_type": { "enum": ["Street", "Avenue", "Boulevard"] }
        },
        "additionalProperties": false
    }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "number": 1600, "street_name": "Pennsylvania", "street_type": "Avenue" }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "number": 1600, "street_name": "Pennsylvania", "street_type": "Avenue", "direction": "NW" }
    `)).length > 0);

    assert(validate!SdliteAdapter(schema, parseSdlang(`
        number 1600
        street_name "Pennsylvania"
        street_type "Avenue"
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        number 1600
        street_name "Pennsylvania"
        street_type "Avenue"
        direction "NW"
    `)).length > 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
    {
        "type": "object",
        "properties": {
            "number": { "type": "number" },
            "street_name": { "type": "string" },
            "street_type": { "enum": ["Street", "Avenue", "Boulevard"] }
        },
        "additionalProperties": { "type": "string" }
    }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "number": 1600, "street_name": "Pennsylvania", "street_type": "Avenue" }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "number": 1600, "street_name": "Pennsylvania", "street_type": "Avenue", "direction": "NW" }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "number": 1600, "street_name": "Pennsylvania", "street_type": "Avenue", "office_number": 201 }
    `)).length > 0);

    assert(validate!SdliteAdapter(schema, parseSdlang(`
        number 1600
        street_name "Pennsylvania"
        street_type "Avenue"
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        number 1600
        street_name "Pennsylvania"
        street_type "Avenue"
        direction "NW"
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        number 1600
        street_name "Pennsylvania"
        street_type "Avenue"
        office_number 201
    `)).length > 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
    {
        "type": "object",
        "properties": {
            "builtin": { "type": "number" }
        },
        "patternProperties": {
            "^S_": { "type": "string" },
            "^I_": { "type": "integer" }
        },
        "additionalProperties": { "type": "string" }
    }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "builtin": 42 }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "keyword": "value" }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "keyword": 42 }
    `)).length > 0);

    assert(validate!SdliteAdapter(schema, parseSdlang(`
        builtin 42
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        keyword "value"
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        keyword 42
    `)).length > 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
   {
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "email": { "type": "string" },
            "address": { "type": "string" },
            "telephone": { "type": "string" }
        },
        "required": ["name", "email"]
    }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        {
            "name": "William Shakespeare",
            "email": "bill@stratford-upon-avon.co.uk"
        }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        {
            "name": "William Shakespeare",
            "email": "bill@stratford-upon-avon.co.uk",
            "address": "Henley Street, Stratford-upon-Avon, Warwickshire, England",
            "authorship": "in question"
        }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        {
            "name": "William Shakespeare",
            "address": "Henley Street, Stratford-upon-Avon, Warwickshire, England",
        }
    `)).length > 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        {
            "name": "William Shakespeare",
            "address": "Henley Street, Stratford-upon-Avon, Warwickshire, England",
            "email": null
        }
    `)).length > 0);
    
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        name "William Shakespeare"
        email "bill@stratford-upon-avon.co.uk"
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        name "William Shakespeare"
        email "bill@stratford-upon-avon.co.uk"
        address "Henley Street, Stratford-upon-Avon, Warwickshire, England"
        authorship "in question"
    `)).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        name "William Shakespeare"
        address "Henley Street, Stratford-upon-Avon, Warwickshire, England"
    `)).length > 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        name "William Shakespeare"
        email null
        address "Henley Street, Stratford-upon-Avon, Warwickshire, England"
    `)).length > 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
    {
        "type": "object",
        "propertyNames": {
            "pattern": "^[A-Za-z_][A-Za-z0-9_]*$"
        }
    }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        {
            "_a_proper_token_001": "value"
        }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        {
            "001 invalid": "value"
        }
    `)).length > 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
    {
        "type": "object",
        "minProperties": 2,
        "maxProperties": 3
    }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        {
        }
    `)).length > 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "a": 0 }
    `)).length > 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "a": 0, "b": 1, "c": 2, "d": 3 }
    `)).length > 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "a": 0, "b": 1 }
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        { "a": 0, "b": 1, "c": 2 }
    `)).length == 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
    {
        "type": "string",
        "pattern": "^(\\([0-9]{3}\\))?[0-9]{3}-[0-9]{4}$"
    }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        "(888)555-1212 ext. 532"
    `)).length > 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        "(800)FLOWERS"
    `)).length > 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        "555-1212"
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        "(888)555-1212"
    `)).length == 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
    {
        "type": "number",
        "multipleOf" : 10
    }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        23
    `)).length > 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        0
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        10
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        20
    `)).length == 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
    { "type": "array" }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        [1, 2, 3, 4, 5]
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        [3, "different", { "types" : "of values" }]
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        {"Not": "an array"}
    `)).length > 0);

    // Root is always an object no matter what, unlike in JSON.
    // So here we have to get the first child
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        1 2 3 4 5
    `).children[0]).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        3 "different" "types of values" // also we can't completely map objects as values :(
    `).children[0]).length == 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
    {
        "type": "array",
        "items": {
            "type": "number"
        }
    }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        [1, 2, 3, 4, 5]
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        []
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        [1, 2, "3", 4, 5]
    `)).length > 0);

    assert(validate!SdliteAdapter(schema, parseSdlang(`
        1 2 3 4 5
    `).children[0]).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        1 2 "3" 4 5
    `).children[0]).length > 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
    {
        "type": "array",
        "prefixItems": [
            { "type": "number" },
            { "type": "string" },
            { "enum": ["Street", "Avenue", "Boulevard"] },
            { "enum": ["NW", "NE", "SW", "SE"] }
        ]
    }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        [1600, "Pennsylvania", "Avenue", "NW"]
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        [10, "Downing", "Street"]
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        [1600, "Pennsylvania", "Avenue", "NW", "Washington"]
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        ["Palais de l'Élysée"]
    `)).length > 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        [24, "Sussex", "Drive"]
    `)).length > 0);

    assert(validate!SdliteAdapter(schema, parseSdlang(`
        1600 "Pennsylvania" "Avenue" "NW"
    `).children[0]).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        10 "Downing" "Street"
    `).children[0]).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        1600 "Pennsylvania" "Avenue" "NW" "Washington"
    `).children[0]).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        "Palais de l'Élysée"
    `).children[0]).length > 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        24 "Sussex" "Drive"
    `).children[0]).length > 0);
}

unittest
{
    JsonSchemaStdDefault schema;
    schema.parseSchema(parseJSON(`
    {
        "type": "array",
        "prefixItems": [
            { "type": "number" },
            { "type": "string" },
            { "enum": ["Street", "Avenue", "Boulevard"] },
            { "enum": ["NW", "NE", "SW", "SE"] }
        ],
        "items": false
    }
    `));
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        [1600, "Pennsylvania", "Avenue", "NW"]
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        [1600, "Pennsylvania", "Avenue"]
    `)).length == 0);
    assert(validate!StdJsonAdapter(schema, parseJSON(`
        [1600, "Pennsylvania", "Avenue", "NW", "Washington"]
    `)).length > 0);

    assert(validate!SdliteAdapter(schema, parseSdlang(`
        1600 "Pennsylvania" "Avenue" "NW"
    `).children[0]).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        1600 "Pennsylvania" "Avenue"
    `).children[0]).length == 0);
    assert(validate!SdliteAdapter(schema, parseSdlang(`
        1600 "Pennsylvania" "Avenue" "NW" "Washington"
    `).children[0]).length > 0);
}