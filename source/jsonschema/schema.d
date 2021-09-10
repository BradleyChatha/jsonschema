module jsonschema.schema;

import std, jsonschema;

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

struct JsonSchemaConstraint
{
}

struct JsonSchemaKeyword
{
}

struct JsonSchemaState
{
    string varName;
}

struct JsonSchemaAlgebraic(Types...)
{
    private static union Store
    {
        static foreach(type; Types)
            mixin("type "~__traits(identifier, type)~";");
    }

    // Create an enum with each type as a member.
    mixin((){
        char[] kind;
        kind ~= "enum Kind { _none, ";
        static foreach(type; Types)
            kind ~= __traits(identifier, type)~", ";
        kind ~= " }";
        return kind;
    }());

    private Kind _kind;
    private Store _store;

    static foreach(type; Types)
    {
        this(type value)
        {
            this._kind = mixin("Kind."~__traits(identifier, type));
            mixin("this._store."~__traits(identifier, type)~" = value;");
        }

        bool contains(T)()
        if(is(T == type))
        {
            return this._kind == mixin("Kind."~__traits(identifier, type));
        }

        bool as(T)()
        if(is(T == type))
        {
            assert(this.contains!T, "This algebraic does not contain a "~__traits(identifier, type));
            return mixin("this._store."~__traits(identifier, type));
        }
    }

    Kind kind()
    {
        return this._kind;
    }
}

struct JsonSchema(
    Adapter_,
    States_,
    Constraints_,
    Keywords_,
    Rules_
)
{
    // I'd like to apologise to the compiler for the war crimes I've committed against it.
    private alias MakeInstance(alias T) = T!(typeof(this));
    alias Adapter       = Adapter_;
    alias States        = staticMap!(MakeInstance, States_.Group);
    alias Constraints   = staticMap!(MakeInstance, Constraints_.Group);
    alias Keywords      = staticMap!(MakeInstance, Keywords_.Group);
    alias ConstraintT   = JsonSchemaAlgebraic!Constraints;
    alias Rules         = Rules_;

    static foreach(state; States)
        mixin("state "~getUDAs!(state, JsonSchemaState)[0].varName~";");

    void parse(Adapter.AggregateType value)
    {
        const valueType = Adapter.getType(value);
        if(valueType == JsonSchemaType.boolean)
        {
            this.common.type = JsonSchemaType._blanket;
            this.common.blanketValue = Adapter.getBoolean(value);
            return;
        }
        else if(valueType != JsonSchemaType.object)
            throw new Exception("A schema must be an object, true, or false. Not: "~valueType.to!string);

        Adapter.eachObjectProperty(value, (k,v)
        {
            switch(k)
            {
                static foreach(keyword; Keywords)
                {
                    case keyword.KEYWORD: keyword.handle(this, v); return;
                }

                static foreach(constraint; Constraints)
                {
                    case constraint.KEYWORD: this.common.constraints ~= ConstraintT(constraint(v)); return;
                }

                default: break;
            }
        });
    }
}

alias T = JsonSchema!(
    StdJsonAdapter,
    AliasGroup!(
        JsonCommonState,
        JsonObjectState
    ),
    AliasGroup!(
        JsonSchemaMinLengthConstraint,
        JsonSchemaMaxLengthConstraint,
        JsonSchemaPatternConstraint,

        JsonSchemaMultipleOfConstraint,
        JsonSchemaMinimumConstraint,
        JsonSchemaMaximumOfConstraint,
        
        JsonSchemaRequiredConstraint,
        JsonSchemaMinPropertiesConstraint,
        JsonSchemaMaxPropertiesConstraint
    ),
    AliasGroup!(
        JsonSchemaTypeKeyword,
        JsonSchemaPropertiesKeyword,
        JsonSchemaPatternPropertiesKeyword,
        JsonSchemaAdditionalPropertiesKeyword,
    ),
    AliasGroup!()
);

unittest
{
    T t;
    t.parse(parseJSON(`{
        "type": "string",
        "minLength": 0,
        "maxLength": 100,
        "pattern": "^gay$",
        "multipleOf": 10,
        "minimum": 200,
        "maximum": 400,
        "properties": {
            "number": { "type": "number" },
            "street_name": { "type": "string" },
        },
        "patternProperties": {
            "^S_": { "type": "string" },
            "^I_": { "type": "integer" }
        },
        "additionalProperties": false,
        "required": ["name", "email"]
    }`));
}

struct AliasGroup(Group_...)
{
    alias Group = Group_;
}

void schemaEnforceType(JsonSchemaType expected, JsonSchemaType got)
{
    enforce(
        got & expected,
        "Expected value of type '%s' but got '%s'".format(
            expected, got
        )
    );
}

void schemaEnforceArrayOf(Adapter)(JsonSchemaType type, Adapter.AggregateType value)
{
    const valueType = Adapter.getType(value);
    schemaEnforceType(JsonSchemaType.array, valueType);
    Adapter.eachArrayValue(value, (i,v) => schemaEnforceType(type, Adapter.getType(v)));
}