# frozen_string_literal: true

require 'mhv/user_account/creator'

module MHV
  class AccountCreatorJob
    include Sidekiq::Job

    sidekiq_options retry: false

    def perform(id)
      user_verification = UserVerification.find(id)
      mhv_user_account = MHV::UserAccount::Creator.new(user_verification:).perform

      mhv_user_account
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error("MHV AccountCreatorJob failed: UserVerification not found for id #{id}")
    end
  end
end
