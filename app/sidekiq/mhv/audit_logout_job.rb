# frozen_string_literal: true

module MHV
  class AuditLogoutJob
    include Sidekiq::Job

    sidekiq_options retry: false

    def perform(mhv_correlation_id, mhv_last_signed_in = nil, user_account_id = nil)
      return if mhv_correlation_id.blank? || mhv_last_signed_in.blank?

      MHVLogging::Client.new(session: { user_id: mhv_correlation_id })
                        .authenticate
                        .auditlogout

      if user_account_id.present?
        update_user_with_account(user_account_id)
      else
        update_users_with_correlation_id(mhv_correlation_id)
      end
    end

    private

    def update_user_with_account(user_account_id)
      user_account = UserAccount.find_by(id: user_account_id)
      user_verification = user_account&.user_verifications&.last
      if user_verification&.user_uuid
        user = User.find(user_verification.user_uuid)
        user.mhv_last_signed_in = nil
        user.save
      end
    end

    def update_users_with_correlation_id(mhv_correlation_id)
      # Skip if UserIdentity doesn't exist or doesn't respond to where
      return unless defined?(UserIdentity) && UserIdentity.respond_to?(:where)
      
      begin
        user_identities = UserIdentity.where(mhv_correlation_id:)
        user_identities.each do |identity|
          user = User.find(identity.uuid)
          user.mhv_last_signed_in = nil
          user.save
        end
      rescue => e
        Rails.logger.error("Error updating users for MHV correlation ID #{mhv_correlation_id}: #{e.message}")
      end
    end
  end
end
