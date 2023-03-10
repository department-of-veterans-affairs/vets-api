# frozen_string_literal: true

require 'appeals_api/token_validation_client'

def with_openid_auth(scopes = %w[], valid: true, &block)
  auth_token = 'TEST_TOKEN'

  allow_any_instance_of(AppealsApi::TokenValidationClient)
    .to receive(:permitted_scopes).and_return scopes

  VCR.use_cassette("token_validation/v3/indicates_token_is_#{valid ? '' : 'in'}valid") do
    block.call(scopes.empty? ? {} : { 'Authorization' => "Bearer #{auth_token}" })
  end
end

shared_examples 'an endpoint with OpenID auth' do |required_scopes, success_status = :ok|
  def make_request(_auth_header = {})
    raise "Pass a block to these shared examples and define a 'make_request' method inside. " \
          'It should take one argument (a hash providing an Authorization header) and use it to ' \
          'make a successful request to the endpoint under test.'
  end

  it 'errors without an Authorization header' do
    make_request({})
    expect(response).to have_http_status(:unauthorized)
  end

  it 'errors without a correctly formatted Authorization header' do
    make_request({ 'Authorization' => 'incorrect-format' })
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects an invalid token' do
    with_openid_auth(required_scopes, valid: false) do |auth_header|
      make_request(auth_header)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  unless required_scopes.empty?
    it 'rejects a valid token with the wrong scopes' do
      with_openid_auth(%w[arbitrary.wrong]) do |auth_header|
        make_request(auth_header)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  it 'succeeds given a valid token with expected scopes' do
    with_openid_auth(required_scopes) do |auth_header|
      make_request(auth_header)
      expect(response).to have_http_status(success_status)
    end
  end

  it 'succeeds given a valid token with the default appeals_api-wide scopes' do
    default_scopes = AppealsApi::OpenidAuth::DEFAULT_OAUTH_SCOPES.values.flatten.uniq
    with_openid_auth(default_scopes) do |auth_header|
      make_request(auth_header)
      expect(response).to have_http_status(success_status)
    end
  end
end
