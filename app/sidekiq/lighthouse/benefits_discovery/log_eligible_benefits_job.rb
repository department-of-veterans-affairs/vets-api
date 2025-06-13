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
        params = ::BenefitsDiscovery::Params.new(user_uuid).prepared_params
        eligible_benefits = ::BenefitsDiscovery::Service.new.get_eligible_benefits(params)
        execution_time = Time.current - start_time
        StatsD.measure(self.class.name, execution_time)

        # Log benefits in an idempotent way
        sorted_benefits = deep_sort_hash(eligible_benefits)
        StatsD.increment(sorted_benefits.to_json)
      rescue => e
        Rails.logger.error("Failed to process BenefitsDiscovery for user: #{user_uuid}, error: #{e.message}")
        raise e
      end

      private

      # Recursively sort hash keys and arrays for idempotent logging
      def deep_sort_hash(obj)
        case obj
        when Hash
          # Sort hash by keys and apply recursively to values
          obj.keys.sort.index_with do |key|
            deep_sort_hash(obj[key])
          end
        when Array
          # If array contains hashes, sort them by their string representation
          if obj.all? { |item| item.is_a?(Hash) }
            obj.map { |item| deep_sort_hash(item) }.sort_by(&:to_s)
          else
            obj.map { |item| deep_sort_hash(item) }
          end
        else
          obj
        end
      end
    end
  end
end
