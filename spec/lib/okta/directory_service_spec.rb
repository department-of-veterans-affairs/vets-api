# frozen_string_literal: true

require 'rails_helper'
require 'okta/directory_service'
require 'okta/service'
require 'vcr'

RSpec.describe Okta::DirectoryService do
  let(:subject) { described_class.new }

  describe '#scopes' do
    it 'directs to #handle_health_server as expected' do
      allow_any_instance_of(Okta::DirectoryService).to receive(:scopes).with('health').and_return('boop')
      expect(subject.scopes('health')).to be('boop')
    end

    it 'directs to #handle_nonhealth_server as expected' do
      allow_any_instance_of(Okta::DirectoryService).to receive(:scopes).with('verification').and_return('beep')
      expect(subject.scopes('verification')).to be('beep')
    end

    it 'handles JSON::ParserError' do
      allow(RestClient::Request).to receive(:execute).and_return(double(code: 200, body: 'invalid_json_response'))
      response = subject.scopes('invalid_category')
      expect(response).to eq({ 'error' => 'Failed to parse JSON response' })
    end
  end

  describe '#handle_health_server' do
    it 'returns a body' do
      VCR.use_cassette('okta/health_scopes', match_requests_on: %i[method path]) do
        response = subject.scopes('health')
        expect(response).not_to be_nil
      end
    end
  end

  describe '#handle_nonhealth_server' do
    it 'handles nonhealth servers as expected' do
      VCR.use_cassette('okta/verification_scopes', match_requests_on: %i[method path]) do
        response = subject.scopes('verification')
        expect(response).not_to be_nil
      end
    end

    it 'returns an empty server when passed an invalid category' do
      VCR.use_cassette('okta/invalid_scopes', match_requests_on: %i[method path]) do
        response = subject.scopes('invalid_category')
        expect(response).to eq([])
      end
    end
  end
end
