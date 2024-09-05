# frozen_string_literal: true

module Authentication
  def login_as(representative_user, options = {})
    access_token = options[:access_token] || create(:access_token, user_uuid: representative_user.uuid,
                                                                   audience: ['arp'])
    cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] =
      SignIn::AccessTokenJwtEncoder.new(access_token:).perform
  end
end

RSpec.configure do |config|
  config.include Authentication
end
