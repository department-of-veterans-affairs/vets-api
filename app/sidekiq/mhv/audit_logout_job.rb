# frozen_string_literal: true

module MHV
  class AuditLogoutJob
    include Sidekiq::Job

    sidekiq_options retry: false

    def perform(mhv_correlation_id, mhv_last_signed_in = nil)
      return if mhv_correlation_id.blank? || mhv_last_signed_in.blank?

      MHVLogging::Client.new(session: { user_id: mhv_correlation_id })
                        .authenticate
                        .auditlogout
    end
  end
end
