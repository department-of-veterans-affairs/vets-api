# frozen_string_literal: true

require 'lighthouse/benefits_discovery/service'
require 'lighthouse/benefits_discovery/params'

module Lighthouse
  module BenefitsDiscovery
    class LogEligibleBenefitsJob
      include Sidekiq::Job

      sidekiq_options retry: false

      def perform(user_uuid)
        start_time = Time.current
        eligible_benefits = ::BenefitsDiscovery::Service.new.get_eligible_benefits(user_uuid)
        execution_time = Time.current - start_time
        StatsD.measure(self.class.name, execution_time)
        sorted_benefits = sort_benefits(eligible_benefits)
        StatsD.increment(sorted_benefits.to_s)
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
    end
  end
end
