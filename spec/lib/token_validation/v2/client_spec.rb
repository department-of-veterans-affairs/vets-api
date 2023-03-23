# frozen_string_literal: true

require 'rails_helper'
require 'token_validation/v2/client'

describe 'token validation' do # rubocop:disable RSpec/DescribeClass
  let(:api_key) { 'abcd1234abcd1234abcd1234abcd1234abcd1234' }
  let(:client) { TokenValidation::V2::Client.new(api_key:) }
  let(:audience) { 'https://dev-api.va.gov/services/some-api' }
  let(:token) { 'ABC123' }
  let(:scope) { 'some_resource.read' }

  it 'indicates token is valid', vcr: 'token_validation/v2/indicates token is valid' do
    response = client.token_valid?(audience:, token:, scope:)

    expect(response).to be true
  end

  it 'indicates token is invalid', vcr: 'token_validation/v2/indicates token is invalid' do
    response = client.token_valid?(audience:, token:, scope:)

    expect(response).to be false
  end

  context 'when token is valid, but is not granted access for the requested scope' do
    scope = 'some_invalid_scope.read'
    it 'indicates token is invalid', vcr: 'token_validation/v2/indicates token is valid' do
      response = client.token_valid?(audience:, token:, scope:)

      expect(response).to be false
    end
  end
end
