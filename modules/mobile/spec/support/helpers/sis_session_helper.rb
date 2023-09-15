# frozen_string_literal: true

module SISSessionHelper
  def sis_access_token
    @sis_access_token ||= create(:access_token)
  end

  def sis_bearer_token
    @sis_bearer_token ||= SignIn::AccessTokenJwtEncoder.new(access_token: sis_access_token).perform
  end

  def sis_user(trait: :api_auth, args: {})
    @sis_user ||= begin
      user_args = { uuid: sis_access_token.user_uuid }.merge(args)
      create(:user, trait, **user_args)
    end
  end

  def sis_headers(additional_headers: {})
    headers = {
      'Authorization' => "Bearer #{sis_bearer_token}",
      'X-Key-Inflection' => 'camel',
      'Authentication-Method' => 'SIS'
    }
    headers.merge!(additional_headers)
  end
end

RSpec.configure do |config|
  config.include SISSessionHelper
end
