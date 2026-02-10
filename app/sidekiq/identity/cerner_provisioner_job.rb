# frozen_string_literal: true

module Identity
  class CernerProvisionerJob
    include Sidekiq::Job

    sidekiq_options retry: false, unique_for: 5.minutes

    # remove 'source' argument from unique check
    def self.sidekiq_unique_context(job)
      args = job['args'].dup
      args.pop if args.size == 2

      [job['class'], job['queue'], args]
    end

    def perform(icn, source = nil)
      CernerProvisioner.new(icn:, source:).perform
    rescue Errors::CernerProvisionerError => e
      Rails.logger.error('[Identity] [CernerProvisionerJob] error', { icn:, error_message: e.message, source: })
      raise if source.to_s == 'tou'
    end
  end
end
