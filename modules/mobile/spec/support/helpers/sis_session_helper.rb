# frozen_string_literal: true

module SISSessionHelper
  def sis_access_token
    @sis_access_token ||= create(:access_token)
  end

  def sis_bearer_token
    @sis_bearer_token ||= SignIn::AccessTokenJwtEncoder.new(access_token: sis_access_token).perform
  end

  def sis_user(traits: [:api_auth], attributes: {})
    @sis_user ||= begin
      user_attributes = { uuid: sis_access_token.user_uuid }.merge(attributes)
      create(:user, *traits, **user_attributes)
    end
  end

  def sis_headers(additional_headers: {}, camelize: true, json: false)
    headers = {
      'Authorization' => "Bearer #{sis_bearer_token}",
      'Authentication-Method' => 'SIS'
    }
    headers.merge!('X-Key-Inflection' => 'camel') if camelize
    headers.merge!({ 'Content-Type' => 'application/json', 'Accept' => 'application/json' }) if json
    headers.merge!(additional_headers) if additional_headers.any?
    headers
  end
end

RSpec.configure do |config|
  config.include SISSessionHelper
end
