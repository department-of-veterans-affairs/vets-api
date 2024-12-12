if defined?(Rails::Console)
  ORIGINAL_FILTERS = Rails.application.config.filter_parameters.dup
end
