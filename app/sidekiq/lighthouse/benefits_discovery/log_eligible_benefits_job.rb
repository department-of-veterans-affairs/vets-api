# frozen_string_literal: true

require 'lighthouse/benefits_discovery/service'
require 'lighthouse/benefits_discovery/params'

module Lighthouse
  module BenefitsDiscovery
    class LogEligibleBenefitsJob
      include Sidekiq::Job

      sidekiq_options retry: false

      def perform(user_uuid, service_history)
        start_time = Time.current
        user = User.find(user_uuid)
        raise Common::Exceptions::RecordNotFound, "User with UUID #{user_uuid} not found" if user.nil?

        prepared_params = ::BenefitsDiscovery::Params.new(user).build_from_service_history(service_history)
        service = ::BenefitsDiscovery::Service.new(
          api_key: Settings.lighthouse.benefits_discovery.x_api_key,
          app_id: Settings.lighthouse.benefits_discovery.x_app_id
        )
        eligible_benefits = service.get_eligible_benefits(prepared_params)
        execution_time = Time.current - start_time
        StatsD.measure(self.class.name, execution_time)
        sorted_benefits = sort_benefits(eligible_benefits)
        formatted_benefits = format_benefits(sorted_benefits)
        StatsD.increment('benefits_discovery_logging', tags: ["eligible_benefits:#{formatted_benefits}"])
      rescue => e
        Rails.logger.error("Failed to process eligible benefits for user: #{user_uuid}, error: #{e.message}")
        raise e
      end

      private

      def sort_benefits(benefit_recommendations)
        benefit_recommendations.transform_values do |benefits|
          benefits.map { |benefit| benefit['benefit_name'] }.sort
        end.sort
      end

      # datadog converts most non-alphanumeric characters into underscores
      # this series of substitutions is being done to make the tag more readable
      def format_benefits(sorted)
        sorted.to_h.to_s.tr('\/"{}=>', '').tr('[', '/').gsub('], ', '/').gsub(', ', ':').tr(']', '/')
      end
    end
  end
end
