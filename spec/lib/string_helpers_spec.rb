require 'spec_helper'
require 'string_helpers'

describe StringHelpers do
  test_method(
    described_class,
    'capitalize_only',
    [
      [
        'fooBar',
        'FooBar'
      ],
      [
        'FooBar',
        'FooBar'
      ]
    ]
  )
end
