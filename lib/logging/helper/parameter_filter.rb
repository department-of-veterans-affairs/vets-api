# frozen_string_literal: true

module Logging
  module Helper
    # This helper provides a method to filter parameters
    #
    # @example
    #     # Filter sensitive data, keeping only allowed parameters
    #     params = {
    #       veteran_ssn: '123-45-6789',
    #       email: 'veteran@example.com',
    #       form_id: '21P-527EZ',
    #       statsd: 'submission_success'
    #     }
    #
    #     filtered = filter_params(params, allowlist: ['form_id', 'statsd'])
    #     # => { veteran_ssn: '[FILTERED]', email: '[FILTERED]', form_id: '21P-527EZ', statsd: 'submission_success' }
    #
    # Note:
    # When running in Rails Console, Rails.application.config.filter_parameters == []
    # The filtering lambda gets reset in `console_filter_toggles.rb#reveal!`
    module ParameterFilter
      module_function

      # filter disallowed parameters from logging payload
      #
      # @param params [Mixed] the parameters to be filtered, typically a Hash or Array<Hash>
      # @param allowlist [Array<String>] the list of allowed parameters
      #
      # @return [Mixed] filtered parameter values
      def filter_params(params, allowlist: [])
        # using the global config to flag if parameters should be filtered
        filter_parameters = Rails.application.config.filter_parameters

        return params unless filter_parameters # nil or false
        return params if filter_parameters.try(:empty?) # empty array; undefined lambda

        allowlist = allowlist.map(&:to_s).uniq
        filter_param(nil, params.deep_dup, allowlist)
      end

      # check if a key/value pair should be filtered
      #
      # @param key [String] the parameter name
      # @param value [Mixed] the associated value
      # @param allowlist [Array<String>] the list of allowed parameters
      #
      # @return [Mixed] "[FILTERED]" or value
      def filter_param(key, value, allowlist)
        # Apply filtering only if the key is NOT in the ALLOWLIST
        return '[FILTERED]' if key && allowlist.exclude?(key.to_s)

        case value
        when Hash # Recursively iterate over each key value pair in hashes
          value.each do |nested_key, nested_value|
            value[nested_key] = filter_param(nested_key, nested_value, allowlist)
          end
        when Array # Recursively map all elements in arrays
          value.map! { |element| filter_param(key, element, allowlist) }
        end

        value
      end

      # ParameterFilter
    end
    # Helper
  end
end
