# frozen_string_literal: true

module Logging
  module Helper
    # ParameterFilter
    #
    # This helper provides a method to filter parameters using the lambda
    # defined in Rails.application.config.filter_parameters.
    #
    # Logging::Helper::ParameterFilter.filter_params({statsd: 'gggg', notallowed: 23,  form_id: 'TEST'}, allowlist: ['statsd', 'form_id'])
    #
    # Note:
    # When running in Rails Console, Rails.application.config.filter_parameters == []
    # The filtering lambda gets reset in `console_filter_toggles.rb#reveal!`
    # The filter_parameters chain will return nil since there is no lambda to call.
    module ParameterFilter
      class << self

        # filter disallowed parameters from logging payload
        def filter_params(params, allowlist: [])
          should_filter = Rails.application.config.filter_parameters
          return params if !should_filter || !!should_filter&.try(:empty?)

          filter_param
        end

        private

        def filter_param
          'FILTERED'
        end
      end
    end
  end
end
