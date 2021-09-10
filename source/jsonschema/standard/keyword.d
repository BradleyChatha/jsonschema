module jsonschema.standard.keyword;

import std, jsonschema;

struct JsonSchemaTypeKeyword(SchemaT)
{
    static:
    
    immutable KEYWORD = "type";

    void handle(ref SchemaT schema, SchemaT.Adapter.AggregateType value)
    {
        schemaEnforceType(JsonSchemaType.string_, SchemaT.Adapter.getType(value));
        
        const type = SchemaT.Adapter.getString(value);
        switch(type) with(JsonSchemaType)
        {
            case "string":  schema.common.type = string_; break;
            case "number":  schema.common.type = number; break;
            case "object":  schema.common.type = object; break;
            case "array":   schema.common.type = array; break;
            case "boolean": schema.common.type = boolean; break;
            case "integer": schema.common.type = integer; break;
            case "null":    schema.common.type = null_; break;

            default: throw new Exception("Unknown type: '"~type~"'");
        }
    }
}

struct JsonSchemaPropertiesKeyword(SchemaT)
{
    static:
    
    immutable KEYWORD = "properties";

    void handle(ref SchemaT schema, SchemaT.Adapter.AggregateType value)
    {
        const valueType = SchemaT.Adapter.getType(value);
        schemaEnforceType(JsonSchemaType.object, valueType);

        SchemaT.Adapter.eachObjectProperty(value, (k,v)
        {
            JsonSchemaProperty!SchemaT prop;
            prop.name = k;
            prop.schema.parse(v);
            schema.object.properties ~= prop;
        });
    }
}

struct JsonSchemaPatternPropertiesKeyword(SchemaT)
{
    static:
    
    immutable KEYWORD = "patternProperties";

    void handle(ref SchemaT schema, SchemaT.Adapter.AggregateType value)
    {
        const valueType = SchemaT.Adapter.getType(value);
        schemaEnforceType(JsonSchemaType.object, valueType);

        SchemaT.Adapter.eachObjectProperty(value, (k,v)
        {
            JsonSchemaPatternProperty!SchemaT prop;
            prop.pattern = k.regex;
            prop.schema.parse(v);
            schema.object.patternProperties ~= prop;
        });
    }
}

struct JsonSchemaAdditionalPropertiesKeyword(SchemaT)
{
    static:
    
    immutable KEYWORD = "additionalProperties";

    void handle(ref SchemaT schema, SchemaT.Adapter.AggregateType value)
    {
        const valueType = SchemaT.Adapter.getType(value);
        schemaEnforceType(JsonSchemaType.boolean, valueType);
        schema.object.additionalProperties = new SchemaT();
        schema.object.additionalProperties.parse(value);
    }
}