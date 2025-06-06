# frozen_string_literal: true

module Lighthouse
  module BenefitsDiscovery
    class LogEligibleBenefits
      include Sidekiq::Job

      sidekiq_options retry: false

      def perform

      end
    end
  end
end
