# frozen_string_literal: true

require 'spec_helper'
require 'string_helpers'

describe StringHelpers do
  test_method(
    described_class,
    'capitalize_only',
    [
      %w[
        fooBar
        FooBar
      ],
      %w[
        FooBar
        FooBar
      ]
    ]
  )
end
