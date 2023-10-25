# frozen_string_literal: true

require 'rails/all'

namespace :service_tags do
  desc 'Audit controllers for Traceable concern'
  task audit_controllers: :environment do
    EXCLUDED_PREFIXES = %w[ActionMailbox:: ActiveStorage:: ApplicationController OkComputer:: Rails::].freeze

    def changed_files
      ENV['CHANGED_FILES'] || []
    end

    def controller_info_from_route(route)
      return unless route.defaults[:controller]

      controller_name = "#{route.defaults[:controller].camelize}Controller"
      return unless Object.const_defined?(controller_name)

      controller_class = controller_name.constantize
      exclusive_methods = controller_class.instance_methods(false)
      return if exclusive_methods.empty?

      method_name = exclusive_methods.first
      file_path = controller_class.instance_method(method_name).source_location.first
      relative_path = Pathname.new(file_path).relative_path_from(Rails.root).to_s

      {
        name: controller_name,
        path: relative_path
      }
    end

    def controllers_from_routes(routes)
      routes.map { |route| controller_info_from_route(route) }.compact.uniq { |info| info[:name] }
    end

    def valid_service_tag?(klass)
      klass.ancestors.any? do |ancestor|
        ancestor.included_modules.include?(Traceable) &&
          ancestor.respond_to?(:trace_service_tag) &&
          ancestor.try(:trace_service_tag).present?
      end
    end

    def find_invalid_controllers(controllers)
      errors = []
      warnings = []

      controllers.each do |controller|
        next if EXCLUDED_PREFIXES.any? { |prefix| controller[:name].start_with?(prefix) }

        klass = controller[:name].constantize

        next if valid_service_tag?(klass)

        if changed_files.include?(controller[:path])
          errors << controller
        else
          warnings << controller
        end
      end

      [errors, warnings]
    end

    main_app_controllers = controllers_from_routes(Rails.application.routes.routes)
    engine_controllers = Rails::Engine.subclasses.flat_map { |engine| controllers_from_routes(engine.routes.routes) }

    errors, warnings = find_invalid_controllers(main_app_controllers + engine_controllers)

    errors.each do |controller|
      puts "::error file=#{controller[:path]}::#{controller[:name]} is missing a service tag."
    end
    
    warnings.each do |controller|
      puts "::warning file=#{controller[:path]}::#{controller[:name]} is missing a service tag."
    end

    exit(errors.any? ? 1 : 0)
  end
end
