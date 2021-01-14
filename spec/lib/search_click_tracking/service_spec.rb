# frozen_string_literal: true

require 'rails_helper'
require 'search_click_tracking/service'

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

  before do
    allow_any_instance_of(described_class).to receive(:access_key).and_return('TESTKEY')
  end

  describe 'when successful' do
    it 'returns a status of 200', :aggregate_failures do
      VCR.use_cassette('search_click_tracking/success', VCR::MATCH_EVERYTHING) do
        response = subject.track_click
        expect(response.status).to eq 200
      end
    end
  end

  #need to mess up params here, which I think this does
  let(:url) { '' }
  let(:query) { '' }
  let(:position) { '' }
  let(:client_ip) { '' }
  let(:user_agent) { '' }

  describe 'error handling' do
    it 'raises a 400 exception' do
      VCR.use_cassette('search_click_tracking/failure', VCR::MATCH_EVERYTHING) do
        expect { subject.track_click }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(400)
          expect(e.errors.first.code).to eq('SEARCH_CLICK_TRACKING_400')
        end
      end
    end
  end 

end
