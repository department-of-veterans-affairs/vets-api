# frozen_string_literal: true

require 'lighthouse/benefits_discovery/service'
require 'lighthouse/benefits_discovery/params'

module Lighthouse
  module BenefitsDiscovery
    class LogEligibleBenefitsJob
      include Sidekiq::Job

      sidekiq_options retry: false

      def perform(user_uuid)
        start_time = Time.now
        params = BenefitsDiscovery::Params.new(user_uuid).prepared_params
        service = BenefitsDiscovery::Service.new
        eligible_benefits = service.get_eligible_benefits(params)
        execution_time = Time.now - start_time
        Rails.logger.info("Processed BenefitsDiscovery params for user: #{user_uuid}, execution_time: #{execution_time.round(2)} seconds")
      rescue => e
        Rails.logger.error("Failed to process BenefitsDiscovery for user: #{user_uuid}, error: #{e.message}")
        raise e
      end
    end
  end
end
