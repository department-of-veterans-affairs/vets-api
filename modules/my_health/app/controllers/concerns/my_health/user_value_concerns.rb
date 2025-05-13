# frozen_string_literal: true

require 'mhv/aal/client'

module MyHealth
  # This module provides overrides for user identity fields (such as ICN, EDIPI, etc.)
  # in development environments to simplify local testing. It redefines certain
  # methods on the `current_user` object to return fixed, testable values.
  #
  # Usage:
  # Include this module in a controller or base controller where `current_user`
  # is defined. In development mode, the overridden values will be returned
  # for user attributes such as `icn`, `mhv_correlation_id`, `edipi`, and `last_name`.
  #
  # The `current_user` object is not replaced—-only the specified methods are
  # dynamically overridden, preserving all other behaviors of the user object.
  module UserValueConcerns
    ##
    # Returns the current user, with selected identity fields overridden
    # for development environment only.
    #
    # @return [Object] The current user with overridden attribute methods
    #
    def current_user
      user = super
      return user unless Rails.env.development?

      # Uncomment and modify these values as desired.
      override_user_fields(user, {
                             #  icn: '1000000000V000000',
                             #  mhv_correlation_id: 10_000_000,
                             #  edipi: '10000000',
                             #  last_name: 'Tester'
                           })
    end

    ##
    # Dynamically overrides selected methods on the user object with provided values.
    #
    # @param user [Object] The user object to override methods on
    # @param fields [Hash] A hash of method names and their return values
    # @return [Object] The same user object with singleton methods added
    #
    def override_user_fields(user, fields)
      fields.each do |key, value|
        user.define_singleton_method(key) { value }
      end
      user
    end
  end
end
