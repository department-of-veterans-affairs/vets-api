# frozen_string_literal: true

class AfterLoginJob
  include Sidekiq::Worker
  include Accountable

  sidekiq_options(retry: false)

  def perform(opt)
    Sentry::TagRainbows.tag
    user_uuid = opt['user_uuid']
    return if user_uuid.blank?
    @current_user = User.find(user_uuid)
    return if @current_user.blank?

    if @current_user.authorize(:evss, :access?)
      auth_headers = EVSS::AuthHeaders.new(@current_user).to_h
      EVSS::CreateUserAccountJob.perform_async(auth_headers)
    end

    create_user_account
  end
end
