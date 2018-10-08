# frozen_string_literal: true

class AfterLoginJob
  include Sidekiq::Worker

  sidekiq_options(retry: false)

  def perform(user_uuid)
    Sentry::TagRainbows.tag
    return if user_uuid.blank?
    user = User.find(user_uuid)
    return if user.blank?

    if user.authorize(:evss, :access?)
      auth_headers = EVSS::AuthHeaders.new(user).to_h
      EVSS::CreateUserAccountJob.perform_async(auth_headers)
    end
  end
end
