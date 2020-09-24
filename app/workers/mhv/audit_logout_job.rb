# frozen_string_literal: true

module MHV
  class AuditLogoutJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(uuid, mhv_correlation_id)
      MHVLogging::Client.new(session: { user_id: mhv_correlation_id })
                        .authenticate
                        .auditlogout
      # Update the user object with nil to indicate not logged in
      user = User.find(uuid)

      if user
        user.mhv_last_signed_in = nil
        user.save
      end
    end
  end
end
