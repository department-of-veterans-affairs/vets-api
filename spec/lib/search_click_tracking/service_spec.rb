# frozen_string_literal: true

require 'rails_helper'
# require 'search_click_tracking/service'

describe SearchClickTracking::Service do
  subject { described_class.new(url, query, position, client_ip, user_agent) }

  let(:url) { 'https://www.testurl.com' }
  let(:query) { 'testQuery' }
  let(:position) { '0' }
  let(:client_ip) { 'testIP' }
  let(:user_agent) { 'testUserAgent' }

  # I need to get these tests to pass, but don't know how.
  # Anyone who can provide support or assistance would be super appreciated.
  # I have a feeling that the config/betamocks/services_config.yml plays a part in this.

  # before do
  #   allow_any_instance_of(described_class).to receive(:access_key).and_return('TESTKEY')
  # end

  describe 'when successful' do
    it 'returns a status of 200' do
      VCR.use_cassette('search_click_tracking/success') do
        response = subject.track_click
        expect(response.status).to eq 200
      end
    end
  end

  describe 'with empty params' do
    let(:url) { '' }
    let(:query) { '' }
    let(:position) { '' }
    let(:client_ip) { '' }
    let(:user_agent) { '' }

    it 'raises a 400 exception' do
      VCR.use_cassette('search_click_tracking/failure') do
        response = subject.track_click
        expect(response.status).to eq 200
      end
    end
  end
end
