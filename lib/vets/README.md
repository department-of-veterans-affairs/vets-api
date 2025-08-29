# Vets lib Overview

`vets` is a directory under `lib` containing modules and classes to extend plain old ruby objects (POROs) with attributes, filtering, sorting, and type coercion. It can be used in place of Virtus, `Common::Base`, and `Common::Collection`.  

# Vets::Model

`Vets::Model` has similar functionality to the discontinued [Virtus gem](https://github.com/solnic/virtus) and `Common::Base`. This is accomplished through [ActiveModel::Model](https://api.rubyonrails.org/classes/ActiveModel/Model.html) and `Vets::Attributes` which is modeled after [ActiveModel::Attributes](https://api.rubyonrails.org/classes/ActiveModel/Attributes.html).  

## Methods 

`attributes`

Returns all the attributes and values in a `HashWithIndifferentAccess`. 

*Future plan:* This will return a Hash and `.with_indifferent_access` will be used as need outside the class

`attribute_values`

Returns all the attributes and values in a `Hash`.

*Future plan:* This method is likely to be deprecated and shouldn't be used.

`attribute_set`

Returns an array of attribute names as symbols including the objects ancestors. 

`changed?`

Returns boolean if variables have changed from the original attributes

`changed`

Returns array of changed variables. If no variables changed it will be an empty array. 

`changes`

Returns hash of changed attributes and the original and current values for each change.

`self.set_pagination(per_page:, max_per_page:)`

This allows for pagination via Vets::Collection. Each class can have it's own pagination attributes by using this class method. 

`self.default_sort_by(sort_criteria)`

This allows for sorting via Vets::Collection. Alternatively, the spaceship operator (<=>) can be used with the `default_sort_criteria` or can be overwritten on the class to the be used in Arrays.   

### Usage

`vets/model` is *not* autoloaded, so it must be required wherever implemented. Then simply include the module `include Vets::Model`.

```ruby
require 'vets/model'

class MyPoro
  include Vets::Model
end 
``` 

`Vets::Model` is intended to extend POROs with attribute assignment, object initialization, attribute coercion and serialization. The attribute class method below creates a dynamic setter and getter methods based on each attribute. 

#### Attributes & Types

```ruby
require 'vets/model'

class SimpleModel
  include Vets::Model

  # attribute :name, Class, default: value, array: true 
  attribute :first_name, String
  attribute :address, Address 
  attribute :occupations, Occupation, array: true 
  attribute :active, Bool, default: true
  attribute :role, String, default: 'admin'
  attribute :created_at, DateTime, :current_time

  private

  def current_time
    DateTime.current
  end
end
```

#### Default Values

All attribute by are nil unless a default is specified. The default value for an attribute can be any Primitive, Array, Hash, method (represented as a symbol), Proc, or lambda.  

```ruby
attribute :name, String, default: 'Guest'
attribute :activated, Bool, default: false
attribute :confirmed_at, default: -> { Time.current }
attribute :occupations, Occupations, array: true, default: []
attribute :metadata, Hash, default: []
attribute :uuid, String, default: :generate_uuid
```

#### Overriding Attribute Values

It maybe required to override a setter or getter. Under the hood of Vets::Model a setter and getter is dynamically created for each attribute. To override them add the method to your class and be sure to use the instance variable for that method

```ruby
def tracked_item_id=(num)
  @tracked_item_id = num == 'null' ? nil : num
end
```

```ruby
def abbreviated_value_example
  @abbreviated_value_example[0..4]
end
```

Alternatively you can override the instance variable value in the initialize method. 

```ruby
def initialize(attributes = {})
  super(attributes)
  @subject = subject ? Nokogiri::HTML.parse(subject).text : nil
end

def initialize(attributes = {})
  super(attributes)
  @ssn = SensitiveInfo.filter(ssn)
end
```

#### Attributes Assignment

Attributes are assigned via hashes or a setter method. Setter methods can be added to classes to override the `attribute` class method and the dynamic setter/getter methods. 

For nested objects, in this case, Occupation and Address, we can input attributes as parameters and they will be coerced into the given class

If an attribute isn't included in the object initialization it will be return nil unless it has a default. 

Booleans and DateTimes can also be casted to their respective class. Such as a string to a datetime. Or a number to a boolean. 

```rb
# Instantiation 
occupation = Occupation.new(...)
SimpleModel.new(
  first_name: 'steven',
  occupations: [occupation],
  active: false,
  role: 'member'
)

#or 

SimpleModel.new(
  first_name: 'steven',
  address: [{city: 'Detroit', street: 'Woodward'}]
  occupations: [{job_title: 'engineer'}],
  active: false,
  role: 'member'
)
```

#### Attribute Coercion

Another primary function of `Vet::Model` is to facilitate attribute coercion. This is performed in `Vets::Type` classes and facilitated through `Vets::Attributes::Value`. Types are loaded with `vets/model`.   

The following are Vets::Types:

- `Array` (can be array of any Object or Primitive)
- `DateTimeString` (returns iso8601 format)
- `Hash`
- `HTTPDate` (returns RFC 7231-compliant date string)
- `ISO8601Time` (only accepts iso8601 format)
- Primitive (String, Bool, Integer, etc)
- `TitlecaseString`
- `UTCTime`
- `XmlDate` (returns string in '%Y-%m-%d' format)

# Vets::Collection

`Vets::Collection` is a class not a module like Vets::Model. This class acts like a super charged array or records. `Vets::Collection` has sorting, finder methods, and pagination.

## Methods & Attributes

`records`

An array of the model class

`metadata`

A hash that hold any type of information a hash can contain. This is typically where pagination information such as the current page is stored.

`errors`

A hash of errors that typically come from external service calls and is passed to the collection. This is *not* the same as ActiveModel::Errors

`self.from_will_paginate(records)`

This method returns a `Vets::Collection` from records of `WillPaginate::Collection`. It **doesn't** include converting the pagination data or any other metadata.

`order(clauses = {})`

This method is inspired by `.order` from `ActiveRecord::QueryMethods`. The clauses should be a hash with the attribute and direction (i.e., :asc or :desc). It also accepts a string and array of strings. Strings are attribute names and a hyphen is used to denote desc order (e.g., "-name" or "name" for descending or ascending respectively). 

`where(conditions = {})`

This method is inspired by  `.where` from `ActiveRecord::QueryMethods`. The conditions are like "filters". Conditions must be hashes where the key is the model attribute. The value must be a hash (called the predicate) with an operation and a operand (a value to perform the operation against). Predicate can have multiple operands. 

Operations: eq, lteq, gteq, not_eq, match

match uses `String#include?` 

```ruby
# attribute = age
# operation = eq
# operand = 40
collection.where(age: { eq: 40 })

collection.where(birthdate: { gteq: 58.years.ago, lteq: 25.years.ago })
``` 

`find_by(conditions = {})`

This method is the exact same as the `where` except it returns the first value. 

`paginate(page: nil, per_page: nil)`

This method returns a new `Vets::Collection` with just paginated records and pagination info stored in the metadata. 

`serialize`

Returns a JSON string that includes the data (records), metadata, and errors. 

`self.fetch(klass, cache_key: nil, ttl: CACHE_DEFAULT_TTL, &block)`

Returns a new `Vets::Collection` from the cache or the results of the block

`self.cache(json_hash, cache_key, ttl)`

Manually cache a hash for a cache key in the collection namespace. `fetch` is the preferred method and `cache` is rarely used. 

`self.bust(cache_keys)`

Manually bust the cache for specified keys in collection namespace. 

### Usage

`vets/collection` is *not* autoloaded, so it must be required wherever implemented. 

The most common use case for `Vets::Collection` is for collecting objects in a response for an external service. 

```ruby
require 'vets/collection'

class SomeClient
  def get_folder
    json = perform_external_call(:get, path, nil, token_headers).body
    Vets::Collection.new(json[:data], Folder)
  end
end
```

#### Caching

Another important feature of Collections is caching

```ruby
def get_history_rxs
  Vets::Collection.fetch(Prescription, cache_key: "#{user_id}:gethistoryrx")) do
    perform(:get, get_path('gethistoryrx'), nil, headers).body
  end
end
```

To manually bust the cache you can use the `.bust` class method 

```ruby
def post_refill_rx(id)
  result = perform(:post, get_path("rxrefill/#{id}"), nil, headers)
  if result.status == 200
    keys = ["#{user_id}:gethistoryrx")]
    Vets::Collection.bust(keys) 
  end
  result
end
```
