# frozen_string_literal: true

require 'mhv/user_account/creator'

module MHV
  class AccountCreatorJob
    include Sidekiq::Job

    sidekiq_options retry: false, unique_for: 5.minutes

    def perform(user_verification_id)
      user_verification = UserVerification.find(user_verification_id)
      MHV::UserAccount::Creator.new(user_verification:, break_cache: true).perform
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error("MHV AccountCreatorJob failed: UserVerification not found for id #{user_verification_id}")
    end
  end
end
