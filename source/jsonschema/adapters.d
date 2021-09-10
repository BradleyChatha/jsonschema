module jsonschema.adapters;

import std, jsonschema, sdlite;

struct StdJsonAdapter
{
    static:

    alias AggregateType = JSONValue;

    JsonSchemaType getType(AggregateType value)
    {
        final switch(value.type) with(JSONType)
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

    bool isNull(AggregateType value) { return value.isNull; }
    string getString(AggregateType value) { return value.str; }
    long getInteger(AggregateType value) { return value.get!ulong; }
    double getNumber(AggregateType value) { return value.get!double; }
    bool getBoolean(AggregateType value) { return value.get!bool; }

    AggregateType getArrayValue(AggregateType value, size_t index) { return value.array[index]; }
    AggregateType getObjectProperty(AggregateType value, string index) { return value.object[index]; }

    void eachArrayValue(AggregateType value, void delegate(size_t, AggregateType) handler)
    {
        foreach(i, v; value.array)
            handler(i, v);
    }

    void eachObjectProperty(AggregateType value, void delegate(string, AggregateType) handler)
    {
        foreach(k, v; value.object)
            handler(k, v);
    }
}

struct SdliteAdapter
{
    static:

    alias AggregateType = SDLNode;

    JsonSchemaType getType(AggregateType value)
    {
        JsonSchemaType type;
        if(value.values.length)
            type |= JsonSchemaType.array;
        if(value.children.length)
            type |= JsonSchemaType.object;

        if(value.values.length == 1)
        {
            final switch(value.values[0].kind) with(SDLValue.Kind)
            {
                case null_:     type |= JsonSchemaType.null_; break;
                case text:      type |= JsonSchemaType.string_; break;
                case binary:    throw new Exception("binary is not supported, at least for now.");
                case int_:      type |= JsonSchemaType.integer | JsonSchemaType.number; break;
                case long_:     type |= JsonSchemaType.integer | JsonSchemaType.number; break;
                case decimal:   type |= JsonSchemaType.number; break;
                case float_:    type |= JsonSchemaType.number; break;
                case double_:   type |= JsonSchemaType.number; break;
                case bool_:     type |= JsonSchemaType.boolean; break;
                case dateTime:  throw new Exception("dateTime is not supported, at least for now");
                case date:      throw new Exception("date is not supported, at least for now");
                case duration:  throw new Exception("duration is not supported, at least for now");
            }
        }

        return type;
    }

    bool isNull(AggregateType value) { return value.values[0].isNull; }
    string getString(AggregateType value) { return value.values[0].textValue; }
    long getInteger(AggregateType value) { return value.values[0].isInt ? value.values[0].intValue : value.values[0].longValue; }
    double getNumber(AggregateType value) { return value.values[0].isFloat ? value.values[0].floatValue : value.values[0].doubleValue; }
    bool getBoolean(AggregateType value) { return value.values[0].boolValue; }

    AggregateType getArrayValue(AggregateType value, size_t index) { return SDLNode("__value", [value.values[index]]); }
    AggregateType getObjectProperty(AggregateType value, string index) { return value.children.filter!(c => c.qualifiedName == index).front; }
    AggregateType getObjectAttribute(AggregateType value, string index) { return SDLNode("__value", [value.getAttribute(index)]); }
}