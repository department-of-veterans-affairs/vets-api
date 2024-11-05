# frozen_string_literal: true

module SISSessionHelper
  def sis_access_token
    @sis_access_token ||= create(:access_token, audience: ['vamobile'])
  end

  def sis_bearer_token
    @sis_bearer_token ||= SignIn::AccessTokenJwtEncoder.new(access_token: sis_access_token).perform
  end

  # Accepts a list of FactoryBot User traits (symbols) and attributes (hashes).
  # example: sis_user(:mhv, mhv_correlation_id: '123')
  # Returns an instance of User created by feeding those values into the user factory along with the api_auth trait.
  # When other traits are provided, it adds api_auth last to ensure that its default values win.
  # The order can be overridden by explicitly including it like: `sis_user(:api_auth, :loa1)`
  def sis_user(*args)
    @sis_user ||= begin
      traits, attributes = args.partition do |arg|
        raise "Invalid user arg: #{arg}\nArg must be a symbol or hash" unless arg.class.in? [Symbol, Hash]

        arg.is_a? Symbol
      end

      user_attributes = { uuid: sis_access_token.user_uuid,
                          session_handle: sis_access_token.session_handle }.merge(*attributes)
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
