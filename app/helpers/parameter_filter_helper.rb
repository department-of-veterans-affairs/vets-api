# frozen_string_literal: true

#
# ParameterFilterHelper
#
# This helper provides a method to filter parameters using the lambda
# defined in Rails.application.config.filter_parameters. Note:
#
# When running in Rails Console, Rails.application.config.filter_parameters
# will be [] because the initializer (config/initializers/filter_parameter_logging.rb)
# which sets up the filtering lambda gets reset in console_filter_toggles.rb.
# In such cases, filter_params will return nil since there is no lambda to call.
#
module ParameterFilterHelper
  def filter_params(params)
    Rails.application.config.filter_parameters.first&.call(nil, params.deep_dup) || params
  end
  module_function :filter_params
end
