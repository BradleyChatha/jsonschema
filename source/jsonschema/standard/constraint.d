module jsonschema.standard.constraint;

import std, jsonschema;

mixin template JsonSchemaIntegerConstraint(string keyword)
{
    static immutable KEYWORD = keyword;

    size_t value;

    this(SchemaT.Adapter.AggregateType value)
    {
        const valueT = SchemaT.Adapter.getType(value);
        schemaEnforceType(JsonSchemaType.integer, valueT);
        this.value = SchemaT.Adapter.getInteger(value);
    }
}

mixin template JsonSchemaRegexConstraint(string keyword)
{
    static immutable KEYWORD = keyword;

    Regex!char value;

    this(SchemaT.Adapter.AggregateType value)
    {
        const valueT = SchemaT.Adapter.getType(value);
        schemaEnforceType(JsonSchemaType.string_, valueT);
        this.value = SchemaT.Adapter.getString(value).regex;
    }
}

mixin template JsonSchemaArrayConstraint(string keyword, JsonSchemaType schemaType, valueType, string getter)
{
    static immutable KEYWORD = keyword;

    valueType value;

    this(SchemaT.Adapter.AggregateType value)
    {
        schemaEnforceArrayOf!(SchemaT.Adapter)(schemaType, value);
        SchemaT.Adapter.eachArrayValue(value, (i,v)
        {
            this.value ~= mixin(getter~"(v)");
        });
    }
}

// strings

struct JsonSchemaMinLengthConstraint(SchemaT)
{
    mixin JsonSchemaIntegerConstraint!"minLength";
}

struct JsonSchemaMaxLengthConstraint(SchemaT)
{
    mixin JsonSchemaIntegerConstraint!"maxLength";
}

struct JsonSchemaPatternConstraint(SchemaT)
{
    mixin JsonSchemaRegexConstraint!"pattern";
}

// numbers

struct JsonSchemaMultipleOfConstraint(SchemaT)
{
    mixin JsonSchemaIntegerConstraint!"multipleOf";
}

struct JsonSchemaMinimumConstraint(SchemaT)
{
    mixin JsonSchemaIntegerConstraint!"minimum";
}

struct JsonSchemaMaximumOfConstraint(SchemaT)
{
    mixin JsonSchemaIntegerConstraint!"maximum";
}

// objects

struct JsonSchemaRequiredConstraint(SchemaT)
{
    mixin JsonSchemaArrayConstraint!("required", JsonSchemaType.string_, string, "SchemaT.Adapter.getString");
}

struct JsonSchemaMinPropertiesConstraint(SchemaT)
{
    mixin JsonSchemaIntegerConstraint!"minProperties";
}

struct JsonSchemaMaxPropertiesConstraint(SchemaT)
{
    mixin JsonSchemaIntegerConstraint!"maxProperties";
}