# frozen_string_literal: true

module Logging
  module Helper
    # ParameterFilter
    #
    # This helper provides a method to filter parameters using the lambda
    # defined in Rails.application.config.filter_parameters.
    #
    # Logging::Helper::ParameterFilter.filter_params({statsd: 'test', notallowed: 23,  form_id: 'TEST'}, allowlist: ['statsd', 'form_id'])
    # => {statsd: 'test', notallowed: '[FILTERED]',  form_id: 'TEST'}
    #
    # Note:
    # When running in Rails Console, Rails.application.config.filter_parameters == []
    # The filtering lambda gets reset in `console_filter_toggles.rb#reveal!`
    # The filter_parameters chain will return nil since there is no lambda to call.
    module ParameterFilter
      module_function

      # filter disallowed parameters from logging payload
      def filter_params(params, allowlist: [])
        filter_parameters = Rails.application.config.filter_parameters
        return params if !filter_parameters || !!filter_parameters&.try(:empty?)

        return params if allowlist && allowlist.empty?

        @allowlist = allowlist.map(&:to_s).uniq
        filter_param(nil, params)
      end

      def filter_param(key, value)
        # Apply filtering only if the key is NOT in the ALLOWLIST
        return '[FILTERED]' if key && @allowlist.exclude?(key.to_s)

        case value
        when Hash # Recursively iterate over each key value pair in hashes
          value.each do |nested_key, nested_value|
            value[nested_key] = filter_param(nested_key, nested_value)
          end
        when Array # Recursively map all elements in arrays
          value.map! { |element| filter_param(key, element) }
        end

        value
      end

    end # ParameterFilter

  end # Helper
end
