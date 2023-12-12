# frozen_string_literal: true

namespace :service_tags do
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
      excluded_prefixes = %w[ActionMailbox:: ActiveStorage:: ApplicationController OkComputer:: Rails::].freeze
      next if excluded_prefixes.any? { |prefix| controller[:name].start_with?(prefix) }

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

  desc 'Audit controllers for Traceable concern usage locally (outside of the CI pipeline)'
  task audit_controllers: :environment do
    main_app_controllers = controllers_from_routes(Rails.application.routes.routes)
    engine_controllers = Rails::Engine.subclasses.flat_map { |engine| controllers_from_routes(engine.routes.routes) }

    _, warnings = find_invalid_controllers(main_app_controllers + engine_controllers)

    if warnings.any?
      puts "\n\nThe following #{warnings.count} controllers are missing service tags. Please associate all " \
           'controllers with a new or existing service catalog entry using the service_tag method from the ' \
           "Traceable concern:\n\n"
      warnings.each do |controller|
        puts controller[:name]
      end
    else
      puts 'All controllers have a service tag!'
    end
  end

  desc 'Audit controllers for Traceable concern usage within a CI pipeline'
  task audit_controllers_ci: :environment do
    main_app_controllers = controllers_from_routes(Rails.application.routes.routes)
    engine_controllers = Rails::Engine.subclasses.flat_map { |engine| controllers_from_routes(engine.routes.routes) }

    errors, warnings = find_invalid_controllers(main_app_controllers + engine_controllers)

    errors.each do |controller|
      puts "::error file=#{controller[:path]}::#{controller[:name]} is missing a service tag. " \
           'Please associate with a service catalog entry using the Traceable#service_tag method.'
    end

    warnings.each do |controller|
      puts "::warning file=#{controller[:path]}::#{controller[:name]} is missing a service tag. " \
           'Please associate with a service catalog entry using the Traceable#service_tag method.'
    end

    exit(errors.any? ? 1 : 0)
  end
end
