# frozen_string_literal: true

class AfterLogoutJob
  include Sidekiq::Worker

  sidekiq_options(retry: false)

  def perform(opt)
    account_uuid = opt['account_uuid']
    return if account_uuid.blank?

    TestUserDashboard::CheckinUser.new(account_uuid).call
  end
end
