# frozen_string_literal: true

module MHV
  class AuditLoginJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(uuid)
      user = User.find(uuid)

      return if user.mhv_last_signed_in

      MHVLogging::Client.new(session: { user_id: user.mhv_correlation_id })
                        .authenticate
                        .auditlogin

      # Update the user object with the time of login
      user.mhv_last_signed_in = Time.current
      user.save
    end
  end
end
