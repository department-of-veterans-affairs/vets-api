# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/logingov/service'

describe SignIn::Logingov::Service do
  let(:code) { '6805c923-9f37-4b47-a5c9-214391ddffd5' }
  let(:token) do
    {
      access_token: 'AmCGxDQzUAr5rPZ4NgFvUQ',
      token_type: 'Bearer',
      expires_in: 900,
      # rubocop:disable Layout/LineLength
      id_token: 'eyJraWQiOiJmNWNlMTIzOWUzOWQzZGE4MzZmOTYzYmNjZDg1Zjg1ZDU3ZDQzMzVjZmRjNmExNzAzOWYLOLQzNjFhMThiMTNjIiwiYWxnIjoiUlMyNTYifQ.eyJzdWIiOiI2NWY5ZjNiNS01NDQ5LTQ3YTYtYjI3Mi05ZDYwMTllN2MyZTMiLCJpc3MiOiJodHRwczovL2lkcC5pbnQuaWRlbnRpdHlzYW5kYm94Lmdvdi8iLCJlbWFpbCPzPmpvaG4uYnJhbWxleUBhZGhvY3RlYW0udXMiLCJlbHqZbF92ZXJpZmllZCI6dHJ1ZSwiZ2l2ZW5fbmFtZSI6IkpvaG4iLCJmYW1pb1bRfbmFtZSI6IkJyYW1sZXkiLCJiaXJ0aGRhdGUiOiIxOTg5LTAzLTI4Iiwic29jaWFsX3NlY3VyaXR5X251bWJlciI6IjA1Ni03Ni03MTQ5IiwidmVyaWZpZWRfYXQiOjE2MzU0NjUyODYsImFjciI6Imh0dHA6Ly9pZG1hbmFnZW1lbnQuZ292L25zL2Fzc3VyYW5jZS9pYWwvMiIsIm5vbmNlIjoiYjIwNjc1ZjZjYmYwYWQ5M2YyNGEwMzE3YWU3Njk5OTQiLCJhdWQiOiJ1cm46Z292OmdzYTpvcGVuaWRjb25uZWN0LnByb2ZpbGVzOnNwOnNzbzp2YTpkZXZfc2lnbmluIiwianRpIjoicjA1aWJSenNXSjVrRnloM1ZuVlYtZyIsImF0X2hhc2giOiJsX0dnQmxPc2dkd0tKemc2SEFDYlJBIiwiY19oYXNoIjoiY1otX2F3OERjSUJGTEVpTE9QZVNFUSIsImV4cCI6MTY0NTY0MTY0NSwiaWF0IjoxNjQ1NjQwNzQ1LCJuYmYiOjE2NDU2NDA3NDV9.S3-8X9clNcwlH2RU5sNoYf9HXpcgVK9UGUJumhL2-3rvznrt6yGvkXvY4FuUzWEcI22muxUjbbsZHjCfDImZ869NTWsI-DKohSNmNnyOom29LJRymJTn3htI5MNmpGwbmNWNuK5HgerPZblL44N1a_rqfTF4lANQX0u52iIVDarcexpX0e9yS1rEPqi3PDdcwN_1tUYox4us9rgzRZaaoa4iTlFfovY7dfgo_ewqv2EDh7JSfJJQhFhyabkJ9HgNkkc4m0SHqztterZ6lHgIoiJdQot6wsL9pQTYzFzgHV830ltpjVUcLG5vMXw4Kqs3BN9tdSToHdB50Paxyfq9kg'
      # rubocop:enable Layout/LineLength
    }
  end
  let(:user_info) do
    {
      sub: '12345678-0990-10a1-f038-2839ab281f90',
      iss: 'https://idp.int.identitysandbox.gov/',
      email: 'user@test.com',
      email_verified: true,
      given_name: 'Bob',
      family_name: 'User',
      birthdate: '1993-01-01',
      social_security_number: '999-11-9999',
      verified_at: 1_635_465_286
    }
  end
  let(:success_callback_url) { 'http://localhost:3001/auth/login/callback?type=logingov' }
  let(:failure_callback_url) { 'http://localhost:3001/auth/login/callback?auth=fail&code=007' }
  let(:state) { 'some-state' }

  describe '#render_auth' do
    let(:response) { subject.render_auth(state: state).to_s }

    it 'renders the logingov_get_form template' do
      expect(response).to include('form id="logingov-form"')
    end

    it 'directs to the Login.gov OAuth authorization page' do
      expect(response).to include('action="https://idp.int.identitysandbox.gov/openid_connect/authorize"')
    end
  end

  describe '#token' do
    it 'returns an access token' do
      VCR.use_cassette('identity/logingov_200_responses') do
        expect(subject.token(code)).to eq(token)
      end
    end
  end

  describe '#user_info' do
    it 'returns a user attributes' do
      VCR.use_cassette('identity/logingov_200_responses') do
        expect(subject.user_info(token)).to eq(user_info)
      end
    end
  end
end
