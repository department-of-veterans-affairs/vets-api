module ParameterFilterHelper
  def filter_params(params)
    Rails.application.config.filter_parameters.first.call(nil, params.deep_dup)
  end
  module_function :filter_params
end
