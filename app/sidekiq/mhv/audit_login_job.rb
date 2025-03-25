# frozen_string_literal: true

module MHV
  class AuditLoginJob
    include Sidekiq::Job

    sidekiq_options retry: false

    def perform(mhv_correlation_id, mhv_last_signed_in = nil, user_account_id = nil)
      # Return early if already signed in or no correlation ID
      return if mhv_last_signed_in.present? || mhv_correlation_id.blank?

      # Perform the MHV audit login using the correlation ID directly
      MHVLogging::Client.new(session: { user_id: mhv_correlation_id })
                        .authenticate
                        .auditlogin

      # If we have a user_account_id, find the user account and update its user
      if user_account_id.present?
        user_account = UserAccount.find_by(id: user_account_id)
        # Find the associated user through user_verification
        user_verification = user_account&.user_verifications&.last
        if user_verification
          user = User.find(user_verification.user_uuid)
          user.mhv_last_signed_in = Time.current
          user.save
        end
      else
        # As a fallback, find all user identities with this mhv_correlation_id and update their users
        user_identities = UserIdentity.where(mhv_correlation_id: mhv_correlation_id)
        user_identities.each do |identity|
          user = User.find(identity.uuid)
          user.mhv_last_signed_in = Time.current
          user.save
        end
      end
    end
  end
end
