# frozen_string_literal: true

class AfterLoginJob
  include Sidekiq::Worker
  include Accountable

  sidekiq_options retry: false, queue: 'critical'

  def evss_create_account
    if @current_user.authorize(:evss, :access?)
      auth_headers = EVSS::AuthHeaders.new(@current_user).to_h
      EVSS::CreateUserAccountJob.perform_async(auth_headers)
    end
  end

  def perform(opt)
    user_uuid = opt['user_uuid']
    return if user_uuid.blank?

    @current_user = User.find(user_uuid)
    return if @current_user.blank?

    evss_create_account
    create_user_account
    TestUserDashboard::CheckoutUser.new(@current_user.account_uuid).call unless Rails.env.production?
  end
end
