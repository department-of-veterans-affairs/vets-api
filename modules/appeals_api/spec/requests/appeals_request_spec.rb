# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Claim Appeals API endpoint', type: :request do
  include SchemaMatchers

  context 'with the X-VA-SSN and X-VA-User header supplied ' do
    it 'returns a successful response' do
      VCR.use_cassette('appeals/appeals') do
        get '/services/appeals/v0/appeals', nil,
            'X-VA-SSN' => '111223333',
            'X-Consumer-Username' => 'TestConsumer',
            'X-VA-User' => 'adhoc.test.user'
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('appeals')
      end
    end

    it 'should log the consumer name' do
      VCR.use_cassette('appeals/appeals') do
        allow(Rails.logger).to receive(:info)
        get '/services/appeals/v0/appeals', nil,
            'X-VA-SSN' => '111223333',
            'X-Consumer-Username' => 'TestConsumer',
            'X-VA-User' => 'adhoc.test.user'
        hash = Digest::SHA2.hexdigest '111223333'
        expect(Rails.logger).to have_received(:info).with('Caseflow Request',
                                                          'consumer' => 'TestConsumer',
                                                          'requested_by' => 'adhoc.test.user',
                                                          'lookup_identifier' => hash)
        expect(Rails.logger).to have_received(:info).with('Caseflow Response',
                                                          'consumer' => 'TestConsumer',
                                                          'requested_by' => 'adhoc.test.user',
                                                          'first_appeal_id' => '1196201',
                                                          'appeal_count' => 3)
      end
    end
  end

  context 'without the X-VA-User header supplied' do
    it 'returns a successful response' do
      VCR.use_cassette('appeals/appeals') do
        get '/services/appeals/v0/appeals', nil,
            'X-VA-SSN' => '111223333',
            'X-Consumer-Username' => 'TestConsumer'
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  context 'without the X-VA-SSN header supplied' do
    it 'returns a successful response' do
      VCR.use_cassette('appeals/appeals') do
        get '/services/appeals/v0/appeals', nil,
            'X-Consumer-Username' => 'TestConsumer',
            'X-VA-User' => 'adhoc.test.user'
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
