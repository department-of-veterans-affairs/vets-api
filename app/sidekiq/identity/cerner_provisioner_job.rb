# frozen_string_literal: true

module Identity
  class CernerProvisionerJob
    include Sidekiq::Job

    sidekiq_options retry: false, unique_for: 5.minutes

    def perform(icn, source = nil)
      CernerProvisioner.new(icn:, source:).perform
    rescue Errors::CernerProvisionerError => e
      Rails.logger.error('[Identity] [CernerProvisionerJob] error', { icn:, error_message: e.message, source: })
    end
  end
end
