# frozen_string_literal: true

require 'mhv/user_account/creator'

module MHV
  class AccountCreatorJob
    include Sidekiq::Job

    sidekiq_options retry: false

    def perform(id, break_cache: false)
      user_verification = UserVerification.find(id)
      MHV::UserAccount::Creator.new(user_verification:, break_cache:).perform
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error("MHV AccountCreatorJob failed: UserVerification not found for id #{id}")
    end
  end
end
