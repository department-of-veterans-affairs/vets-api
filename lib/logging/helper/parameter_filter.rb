# frozen_string_literal: true

module Logging
  module Helper
    # ParameterFilter
    #
    # This helper provides a method to filter parameters using the lambda
    # defined in Rails.application.config.filter_parameters.
    #
    # Note:
    # When running in Rails Console, Rails.application.config.filter_parameters == []
    # The filtering lambda gets reset in `console_filter_toggles.rb#reveal!`
    # The filter_parameters chain will return nil since there is no lambda to call.
    module ParameterFilter
      module_function

      # filter disallowed parameters from logging payload
      def filter_params(params, allowed_params: [])
        return params if defined?(Rails::Console)

        Rails.application.config.filter_parameters.first&.call(nil, params.deep_dup) || params
      end
    end
  end
end
