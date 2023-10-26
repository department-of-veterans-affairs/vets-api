# frozen_string_literal: true

namespace :service_tags do
  desc 'Check service tag compliance for all controllers'
  task compliance: :environment do
    non_compliant_controllers = []

    Rails.application.eager_load!

    (ApplicationController.descendants + SignIn::ApplicationController.descendants).each do |descendant|
      if !descendant.respond_to?(:trace_service_tag) || descendant.trace_service_tag.nil?
        non_compliant_controllers << descendant.name
      end
    end

    if non_compliant_controllers.any?
      puts "\nThere are #{non_compliant_controllers.size} controllers without a service_tag set:\n\n"
      non_compliant_controllers.each { |controller| puts controller }
      abort("\nNon-compliant service tag controllers found.")
    else
      puts 'All controllers are compliant.'
    end
  end
end
