# frozen_string_literal: true

module SISSessionHelper
  def sis_access_token
    @sis_access_token ||= create(:access_token)
  end

  def sis_bearer_token
    @sis_bearer_token ||= SignIn::AccessTokenJwtEncoder.new(access_token: sis_access_token).perform
  end

  def sis_user(*args)
    @sis_user ||= begin
      traits, attributes = args.partition do |arg|
        raise "Invalid user arg: #{arg}\nArg must be a symbol or hash" unless arg.class.in? [Symbol, Hash]

        arg.is_a? Symbol
      end

      user_attributes = { uuid: sis_access_token.user_uuid }.merge(*attributes)
      # adds api_auth last by default to ensure that its default values win
      # the order can be overridden by explicitly including it like `sis_user(:api_auth, :loa1)`
      traits |= [:api_auth]
      create(:user, *traits, **user_attributes)
    end
  end

  def sis_headers(additional_headers = nil, camelize: true, json: false)
    raise 'Must instantiate user by calling `sis_user` before using headers' unless defined?(@sis_user)

    headers = {
      'Authorization' => "Bearer #{sis_bearer_token}",
      'Authentication-Method' => 'SIS'
    }
    headers.merge!('X-Key-Inflection' => 'camel') if camelize
    headers.merge!({ 'Content-Type' => 'application/json', 'Accept' => 'application/json' }) if json
    headers.merge!(additional_headers) if additional_headers
    headers
  end
end

RSpec.configure do |config|
  config.include SISSessionHelper
end
