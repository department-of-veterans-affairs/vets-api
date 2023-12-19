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
  end

  describe '#handle_health_server' do
    it 'returns a body' do
      VCR.use_cassette('okta/health_scopes', match_requests_on: %i[method path]) do
        response = subject.scopes("health")
        expect(response).not_to be_nil
      end
    end
  end

  describe '#handle_nonhealth_server' do
    it 'handles nonhealth servers as expected' do
      VCR.use_cassette('okta/verification_scopes', match_requests_on: %i[method path]) do
        response = subject.scopes("verification")
        expect(response).not_to be_nil
      end
    end
  end
end
