module jsonschema.constraints;

import std, jsonschema;

struct JsonMinPropertiesConstraint
{
    static immutable KEYWORD = "minProperties";

    size_t amount;

    void parse(Adapter)(Adapter.ValueType value)
    {
        this.amount = Adapter.getNumber(value).to!size_t;
    }

    const:

    string validate(ValueAdapter)(ValueAdapter.ValueType value)
    {
        return "Cannot apply minProperties onto the given value.";
    } 
    
    string validate(ValueAdapter)(ValueAdapter.ObjectType value)
    {
        return ValueAdapter.getObjectLength(value) >= this.amount
            ? null
            : "Expected a minimum of %s properties.".format(this.amount);
    }
    
    string validate(ValueAdapter)(ValueAdapter.ArrayType value)
    {
        return "Cannot apply minProperties onto arrays, try minItems instead.";
    }
}

struct JsonMaxPropertiesConstraint
{
    static immutable KEYWORD = "maxProperties";

    size_t amount;

    void parse(Adapter)(Adapter.ValueType value)
    {
        this.amount = Adapter.getNumber(value).to!size_t;
    }

    const:

    string validate(ValueAdapter)(ValueAdapter.ValueType value)
    {
        return "Cannot apply maxProperties onto the given value.";
    } 
    
    string validate(ValueAdapter)(ValueAdapter.ObjectType value)
    {
        return ValueAdapter.getObjectLength(value) <= this.amount
            ? null
            : "Expected a maximum of %s properties.".format(this.amount);
    }
    
    string validate(ValueAdapter)(ValueAdapter.ArrayType value)
    {
        return "Cannot apply maxProperties onto arrays, try maxItems instead.";
    }
}

struct JsonMinItemsConstraint
{
    static immutable KEYWORD = "minItems";

    size_t amount;

    void parse(Adapter)(Adapter.ValueType value)
    {
        this.amount = Adapter.getNumber(value).to!size_t;
    }

    const:

    string validate(ValueAdapter)(ValueAdapter.ValueType value)
    {
        return "Cannot apply minItems onto the given value.";
    } 
    
    string validate(ValueAdapter)(ValueAdapter.ObjectType value)
    {
        return "Cannot apply minItems onto objects, try minProperties instead.";
    }
    
    string validate(ValueAdapter)(ValueAdapter.ArrayType value)
    {
        return ValueAdapter.getArrayLength(value) >= this.amount
            ? null
            : "Expected a minimum of %s items.".format(this.amount);
    }
}

struct JsonMaxItemsConstraint
{
    static immutable KEYWORD = "maxItems";

    size_t amount;

    void parse(Adapter)(Adapter.ValueType value)
    {
        this.amount = Adapter.getNumber(value).to!size_t;
    }

    const:

    string validate(ValueAdapter)(ValueAdapter.ValueType value)
    {
        return "Cannot apply maaxProperties onto the given value.";
    } 
    
    string validate(ValueAdapter)(ValueAdapter.ObjectType value)
    {
        return "Cannot apply maxItems onto objects, try maxProperties instead.";
    }
    
    string validate(ValueAdapter)(ValueAdapter.ArrayType value)
    {
        return ValueAdapter.getArrayLength(value) <= this.amount
            ? null
            : "Expected a maximum of %s items.".format(this.amount);
    }
}

struct JsonUniqueItemsConstraint
{
    static immutable KEYWORD = "uniqueItems";

    bool enabled;

    void parse(Adapter)(Adapter.ValueType value)
    {
        this.enabled = Adapter.getBoolean(value);
    }

    const:

    string validate(ValueAdapter)(ValueAdapter.ValueType value)
    {
        return "Cannot apply uniqueItems onto the given value.";
    } 
    
    string validate(ValueAdapter)(ValueAdapter.ObjectType value)
    {
        return "Cannot apply uniqueItems onto objects, try maxProperties instead.";
    }
    
    string validate(ValueAdapter)(ValueAdapter.ArrayType value)
    {
        return "TODO";
    }
}

struct JsonPatternConstraint
{
    static immutable KEYWORD = "pattern";

    Regex!char pattern;

    void parse(Adapter)(Adapter.ValueType value)
    {
        this.pattern = Adapter.getString(value).regex;
    }

    const:

    string validate(ValueAdapter)(ValueAdapter.ValueType value)
    {
        return matchFirst(ValueAdapter.getString(value), this.pattern)
            ? null
            : "Expected value to match regex %s".format(this.pattern);
    } 
    
    string validate(ValueAdapter)(ValueAdapter.ObjectType value)
    {
        return "Cannot apply pattern onto objects.";
    }
    
    string validate(ValueAdapter)(ValueAdapter.ArrayType value)
    {
        return "Cannot apply pattern onto ararys.";
    }
}

struct JsonMultipleConstraint
{
    static immutable KEYWORD = "multipleOf";

    long amount;

    void parse(Adapter)(Adapter.ValueType value)
    {
        this.amount = Adapter.getNumber(value).to!long;
    }

    const:

    string validate(ValueAdapter)(ValueAdapter.ValueType value)
    {
        return (ValueAdapter.getNumber(value) % this.amount) == 0
            ? null
            : "Expected value to be a multiple of %s".format(this.amount);
    } 
    
    string validate(ValueAdapter)(ValueAdapter.ObjectType value)
    {
        return "Cannot apply pattern onto objects.";
    }
    
    string validate(ValueAdapter)(ValueAdapter.ArrayType value)
    {
        return "Cannot apply pattern onto ararys.";
    }
}