module jsonschema.standard.state;

import std, jsonschema;

struct JsonSchemaProperty(SchemaT)
{
    string name;
    SchemaT schema;
}

struct JsonSchemaPatternProperty(SchemaT)
{
    Regex!char pattern;
    SchemaT schema;
}

@JsonSchemaState("common")
struct JsonCommonState(SchemaT)
{
    JsonSchemaType type;
    SchemaT.ConstraintT[] constraints;
    bool blanketValue; // True = Allow all, False = Disallow all.
}

@JsonSchemaState("object")
struct JsonObjectState(SchemaT)
{
    JsonSchemaProperty!SchemaT[] properties;
    JsonSchemaPatternProperty!SchemaT[] patternProperties;
    SchemaT* additionalProperties; // Must be a pointer to avoid forward referencing.
}