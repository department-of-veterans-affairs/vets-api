# frozen_string_literal: true

namespace :service_tags do
  desc 'Lints all the route connected controllers to ensure they have a service tag'
  task audit_controllers: :environment do
    def find_non_compliant_controllers(routes)
      excluded = %w[ActiveStorage:: ApplicationController OkComputer:: Rails::]
      non_compliant_controllers = Set.new

      routes.each do |route|
        controller_class = controller_class_from_route(route)
        next unless controller_class
        next if excluded.any? { |prefix| controller_class.name.start_with?(prefix) }
        next if valid_service_tag?(controller_class)

        non_compliant_controllers << controller_class.name
      end

      non_compliant_controllers
    end

    def controller_class_from_route(route)
      controller = route.defaults[:controller]
      return unless controller

      controller.camelize.concat('Controller').constantize
    rescue NameError
      nil
    end

    def valid_service_tag?(klass)
      # klass.ancestors includes the top level class
      klass.ancestors.any? do |ancestor|
        ancestor.included_modules.include?(Traceable) &&
          ancestor.respond_to?(:trace_service_tag) &&
          ancestor.try(:trace_service_tag).present?
      end
    end

    non_compliant_controllers = Set.new

    non_compliant_controllers += find_non_compliant_controllers(Rails.application.routes.routes)

    Rails::Engine.subclasses.each do |engine|
      non_compliant_controllers += find_non_compliant_controllers(engine.routes.routes)
    end

    if non_compliant_controllers.any?
      puts "\nNon-compliant Controllers:\n\n"
      non_compliant_controllers.each { |name| puts name }
      puts "\n#{non_compliant_controllers.count} non-compliant controllers found"
      exit 1
    else
      puts 'All controllers are compliant!'
      exit 0
    end
  end
end
