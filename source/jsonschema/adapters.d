module jsonschema.adapters;

import std.json, jsonschema.schema, std.conv;

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

    void each(ObjectType obj, void delegate(string, ValueType) handler)
    {
        foreach(k, v; obj)
            handler(k, v);
    }

    void each(ArrayType array, void delegate(size_t, ValueType) handler)
    {
        foreach(i, v; array)
            handler(i, v);
    }
}