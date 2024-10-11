# frozen_string_literal: true

require 'mhv/user_account/creator'

module MHV
  class AccountCreatorJob
    include Sidekiq::Job

    sidekiq_options retry: false

    def perform(id)
      user_verification = UserVerification.find(id)
      MHV::UserAccount::Creator.new(user_verification:, break_cache: true).perform
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error("MHV AccountCreatorJob failed: UserVerification not found for id #{id}")
    end
  end
end
