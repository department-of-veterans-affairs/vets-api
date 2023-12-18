# frozen_string_literal: true

require 'rails_helper'
require 'okta/directory_service'
require 'vcr'

RSpec.describe Okta::DirectoryService do
  context 'with valid response from okta' do
    it 'directs to #handle_health_server as expected' do
      allow_any_instance_of(Okta::DirectoryService).to receive(:scopes).with('health').and_return('boop')
      expect(subject.scopes('health')).to be('boop')
    end

    it 'directs to #handle_nonhealth_server as expected' do
      allow_any_instance_of(Okta::DirectoryService).to receive(:scopes).with('verification').and_return('beep')
      expect(subject.scopes('verification')).to be('beep')
    end

    it 'handle 200 calls from lh-auth' do
      VCR.use_cassette('okta/health_scopes', match_requests_on: %i[method path]) do
        get '/v0/profile/app_directory_scope/ausa6g29u50OhqAdv2p7'
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
      end
    end
  end
end
