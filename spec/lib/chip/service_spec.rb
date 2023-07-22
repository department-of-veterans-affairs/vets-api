# frozen_string_literal: true

require 'rails_helper'
require 'chip/service'

describe Chip::Service do
  let(:service) { described_class.new }

  describe 'configuration' do
    it 'is of type Configuration' do
      expect(service.class.configuration).to be_a(Chip::Configuration)
    end
  end

  describe 'perform_get_with_token' do
    let(:response) { Faraday::Response.new(body: 'success', status: 200) }
    let(:token) { 'testToken' }
    let(:path) { '/testPath' }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(anything).and_return(response)
    end

    it 'calls Faraday::Connection' do
      expect_any_instance_of(Faraday::Connection).to receive(:get).with(path).and_yield(Faraday::Request.new)
      service.perform_get_with_token(token:, path:)
    end

    it 'returns Faraday::Response' do
      expect(service.perform_get_with_token(token:, path:)).to be_a(Faraday::Response)
    end
  end

  describe 'perform_post_with_token' do
    let(:response) { Faraday::Response.new(body: 'success', status: 200) }
    let(:token) { 'testToken' }
    let(:request_header) do
      {
        'Content-Type' => 'application/json',
        'x-apigw-api-id' => Settings.chip.api_gtwy_id.to_s,
        'Authorization' => "Bearer #{token}"
      }
    end
    let(:request) { Faraday::Request.new(request_header) }
    let(:path) { '/testPath' }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(response)
    end

    it 'calls Faraday::Connection' do
      expect_any_instance_of(Faraday::Connection).to receive(:post).with(path).and_yield(request)
      service.perform_post_with_token(token:, path:)
    end

    it 'returns Faraday::Response' do
      expect(service.perform_post_with_token(token:, path:)).to be_a(Faraday::Response)
    end
  end

  describe 'token' do
    let(:chip_token_response) { Faraday::Response.new(body: { 'token' => 'testToken' }, status: 200) }
    let(:path) { '/token' }
    let(:claims_token) { Base64.encode64('fake_api_user:fake_api_password') }
    let(:request_header) do
      {
        'Content-Type' => 'application/json',
        'x-apigw-api-id' => Settings.chip.api_gtwy_id.to_s,
        'Authorization' => "Basic #{claims_token}"
      }
    end
    let(:request) { Faraday::Request.new(request_header) }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with('/token').and_return(chip_token_response)
    end

    it 'calls Faraday::Connection' do
      expect_any_instance_of(Faraday::Connection).to receive(:post).with(path).and_yield(request)
      service.token
    end

    it 'returns token' do
      expect(service.token).to eq(chip_token_response)
    end
  end
end
