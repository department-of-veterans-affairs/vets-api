# frozen_string_literal: true

module ConsoleFilterStorage
  # We will assign constants here using const_set after initialization
end

module ConsoleFilterToggles
  def reveal!
    Rails.application.config.filter_parameters = []
    ActiveRecord::Base.filter_attributes = []

    ActiveRecord::Base.descendants.each do |model|
      model.filter_attributes = [] if model.respond_to?(:filter_attributes)
    end

    $stdout.puts 'All filters removed: attributes will not be concealed.'
  end

  def conceal!
    Rails.application.config.filter_parameters = ConsoleFilterStorage::ORIGINAL_FILTERS.dup
    ActiveRecord::Base.filter_attributes = ConsoleFilterStorage::ORIGINAL_AR_FILTERS.dup

    ActiveRecord::Base.descendants.each do |model|
      if model.respond_to?(:filter_attributes)
        original_filters = ConsoleFilterStorage::ORIGINAL_MODEL_FILTERS[model.name] || []
        model.filter_attributes = []
        model.filter_attributes.concat(original_filters)
      end
    end

    $stdout.puts 'All filters re-applied: attributes are concealed.'
  end
end

if defined?(Rails::Console)
  Rails.application.config.after_initialize do
    ConsoleFilterStorage.const_set('ORIGINAL_FILTERS', Rails.application.config.filter_parameters.dup.freeze)
    ConsoleFilterStorage.const_set('ORIGINAL_AR_FILTERS', ActiveRecord::Base.filter_attributes.dup.freeze)

    model_filters = {}
    ActiveRecord::Base.descendants.each do |model|
      model_filters[model.name] = model.filter_attributes.dup if model.respond_to?(:filter_attributes)
    end
    ConsoleFilterStorage.const_set('ORIGINAL_MODEL_FILTERS', model_filters.freeze)

    TOPLEVEL_BINDING.eval('self').extend(ConsoleFilterToggles)

    # Automatically reveal! in console
    TOPLEVEL_BINDING.eval('self').reveal!
  end
end
