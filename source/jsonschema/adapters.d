module jsonschema.adapters;

import std.json, jsonschema.schema, std.conv, std.exception;

struct StdJsonAdapter
{
    alias ObjectType = JSONValue[string];
    alias ArrayType  = JSONValue[];
    alias ValueType  = JSONValue;

    static:

    JsonSchemaType getType(ObjectType)
    {
        return JsonSchemaType.object;
    }

    JsonSchemaType getType(ArrayType)
    {
        return JsonSchemaType.array;
    }

    JsonSchemaType getType(ValueType v)
    {
        final switch(v.type) with(JSONType)
        {
            case null_: return JsonSchemaType.null_;
            case string: return JsonSchemaType.string_;
            case integer: return JsonSchemaType.integer | JsonSchemaType.number;
            case uinteger: return JsonSchemaType.integer | JsonSchemaType.number;
            case float_: return JsonSchemaType.number;
            case array: return JsonSchemaType.array;
            case object: return JsonSchemaType.object;
            case true_: return JsonSchemaType.boolean;
            case false_: return JsonSchemaType.boolean;
        }
    }

    bool isNull(T)(T value)
    {
        static if(is(T == ValueType))
            return value.isNull;
        else
            return false;
    }

    string getString(ValueType v)
    {
        return v.str;
    }

    double getNumber(ValueType v)
    {
        if(v.type == JSONType.integer) return v.integer.to!double;
        else if(v.type == JSONType.uinteger) return v.uinteger.to!double;
        else if(v.type == JSONType.float_) return v.floating.to!double;
        else throw new Exception("Value is not numerical.");
    }

    ArrayType getArray(ValueType v)
    {
        return v.array;
    }

    ObjectType getObject(ValueType v)
    {
        return v.object;
    }

    bool getBoolean(ValueType v)
    {
        if(v.type == JSONType.true_) return true;
        else if(v.type == JSONType.false_) return false;
        else throw new Exception("Value is not a boolean.");
    }

    bool getObjectValue(ObjectType obj, string name, out ValueType value)
    {
        scope ptr = (name in obj);
        if(!ptr)
            return false;
        value = *ptr;
        return true;
    }

    ValueType getArrayValue(ArrayType array, size_t index)
    {
        return array[index];
    }

    size_t getArrayLength(ArrayType array)
    {
        return array.length;
    }

    size_t getObjectLength(ObjectType obj)
    {
        return obj.length;
    }

    void objectEach(ObjectType obj, void delegate(string, ValueType) handler)
    {
        foreach(k, v; obj)
            handler(k, v);
    }

    void arrayEach(ArrayType array, void delegate(size_t, ValueType) handler)
    {
        foreach(i, v; array)
            handler(i, v);
    }
}

struct SdliteAdapter
{
    import sdlite;

    alias ObjectType = SDLNode;
    alias ArrayType  = SDLNode;
    alias ValueType  = SDLNode;

    static:

    JsonSchemaType getType(ArrayType v)
    {
        if(v.children.length == 0 && v.values.length)
        {
            if(v.values.length == 1)
            {
                final switch(v.values[0].kind) with(SDLValue.Kind)
                {
                    case null_:     return JsonSchemaType.null_;
                    case text:      return JsonSchemaType.string_;
                    case binary:    throw new Exception("Cannot map SDLang's `binary` type into a JSON type.");
                    case int_:      return JsonSchemaType.number | JsonSchemaType.integer;
                    case long_:     return JsonSchemaType.number | JsonSchemaType.integer;
                    case decimal:   return JsonSchemaType.number;
                    case float_:    return JsonSchemaType.number;
                    case double_:   return JsonSchemaType.number;
                    case bool_:     return JsonSchemaType.boolean;

                    // TODO: Could probably auto-convert these into strings at the very least.
                    case dateTime:  throw new Exception("Cannot map SDLang's `dateTime` type into a JSON type.");
                    case date:      throw new Exception("Cannot map SDLang's `date` type into a JSON type.");
                    case duration:  throw new Exception("Cannot map SDLang's `duration` type into a JSON type.");
                }
            }

            return JsonSchemaType.array;
        }
        else if(v.children.length && v.values.length == 0)
            return JsonSchemaType.object;
        else if (v.children.length == 0 && v.values.length == 0)
            return JsonSchemaType.object; // Treat it as an empty object
        else
            throw new Exception("Cannot map an SDLNode that has both values and children into a JSON type.");
    }

    bool isNull(T)(T value)
    {
        static if(is(T == ValueType))
            return value.isNull;
        else
            return false;
    }

    string getString(ValueType v)
    {
        return v.values[0].textValue;
    }

    double getNumber(ValueType v)
    {
        if(v.values[0].kind == SDLValue.Kind.int_) return v.values[0].intValue.to!double;
        else if(v.values[0].kind == SDLValue.Kind.long_) return v.values[0].longValue.to!double;
        else if(v.values[0].kind == SDLValue.Kind.float_) return v.values[0].floatValue.to!double;
        else if(v.values[0].kind == SDLValue.Kind.double_) return v.values[0].doubleValue.to!double;
        else throw new Exception("Value is not numerical.");
    }

    ArrayType getArray(ValueType v)
    {
        return v;
    }

    ObjectType getObject(ValueType v)
    {
        enforce(v.attributes.length == 0, "Cannot map attributes into JSON Schema.");
        return v;
    }

    bool getBoolean(ValueType v)
    {
        return v.values[0].boolValue;
    }

    bool getObjectValue(ObjectType obj, string name, out ValueType value)
    {
        foreach(child; obj.children)
        {
            if(child.qualifiedName == name)
            {
                value = child;
                return true;
            }
        }

        return false;
    }

    ValueType getArrayValue(ArrayType array, size_t index)
    {
        return SDLNode("__value", [array.values[index]]);
    }

    size_t getArrayLength(ArrayType array)
    {
        return array.values.length;
    }

    size_t getObjectLength(ObjectType obj)
    {
        return obj.children.length;
    }

    void objectEach(ObjectType obj, void delegate(string, ValueType) handler)
    {
        foreach(v; obj.children)
            handler(v.qualifiedName, v);
    }

    void arrayEach(ArrayType array, void delegate(size_t, ValueType) handler)
    {
        foreach(i, v; array.values)
            handler(i, SDLNode("__value", [v]));
    }
}