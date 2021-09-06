# Overview

jsonschema is a D implementation of... [JSON Schema](https://json-schema.org).

It uses a very flexible design to allow for easy extension of the library. For example, using the adapter pattern, you could actually read the schema
from a different language, and also validate a different language against a schema! Schema language and the validated language can also differ.

For example, you can write the schema in JSON, then apply the schema to SDLang.

This also allows for any JSON backend to be used, currently one for `std.json` is bundled.

# Limitations

This is not fully compliant yet, as it only implements the easy stuff:

[x] `type` keyword, and all types
[x] `string`, `length`, `pattern`.
[ ] `format`
[x] `integer`, `number`, `multipleOf`
[ ] `range` (draft 4 adds an annoying requirement I need to think about, basically whether to hard code this one or not)
[x] `object`, `properties`, `patternProperties`, `additionalProperties`, `required`, `propertyName`, `minProperties`, `maxProperties`
[x] `array`, `items`, `prefixItems`, `additionalItems`, `minItems`, `maxItems`
[ ] `uniqueItems` (i'm lazy ;p)
[ ] `contains`
[x] `boolean`
[x] `null`
[x] `title`, `description`
[ ] `default`
[ ] `examples`
[ ] `deprecated`
[ ] `readOnly`
[ ] `writeOnly`
[x] `enum`
[ ] `const`
[ ] `contentMediaType`, `contentEncoding`
[ ] `allOf`, `anyOf`, `oneOf`, `not`
[ ] `dependentRequired`, `dependentSchemas`, `if-then-else`
[ ] `JSON pointers`
[ ] `$anchor`
[ ] `$id`
[ ] `$ref`
[ ] `$defs`
[ ] Sub-Schemas

# Basic usage

Currently this library only supports JSON out of the box via an `std.json` adapter:

* Declare a `JsonSchemaStdDefault`
* Call `.parseSchema` on it, passing in the result of e.g. `std.json.parseJSON` to setup the schema itself.
* Call the freestanding `validate` function, passing in an adapter as the template parameter (e.g. `StdJsonAdapter`), passing in your schema and your value to validate as the runtime parameters.
* `validate` will return a `string[]` containing any errors found. A `null` array means no errors were found and validation was successful.

Here's a unittest to show you the usage:

```d
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
}
```

# Creating an Adapter or a Constraint

For actually creating these things, I suggest looking at the existing `constraints.d` and `adapters.d` files, as that will show you all the required
functions that you need to implement and additional symbols that need to be defined.

Then you need to create an instance of `JsonSchema` that includes your custom adapter (if used for the schema), and any custom constraints, for now you also
have to manually redefine all the standard constraints:

```d
alias MySchema = JsonSchema!(
    MY_ADAPTER,
    SchemaGroup!(
        MY_CONSTRAINT1,
        MY_CONSTRAINT2,

        JsonMaxPropertiesConstraint,
        JsonMinPropertiesConstraint,
        JsonMaxItemsConstraint,
        JsonMinItemsConstraint,
        JsonUniqueItemsConstraint,
        JsonPatternConstraint,
        JsonMultipleConstraint
    )
)
```

And then you can use things just as before, replacing `JsonSchemaStdDefault` with `MySchema`, and optionally any usage of `StdJsonAdapter` with `MY_ADAPTER`.

# Example of using a different language for the schema, and another for the validated value

TODO once I have the SDLang adapater written.