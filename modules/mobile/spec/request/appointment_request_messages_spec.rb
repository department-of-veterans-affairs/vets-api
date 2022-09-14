# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'appointment_request_messages', type: :request do
  include JsonSchemaMatchers

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  before do
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('1012845331V153043')
    iam_sign_in(build(:iam_user))
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe '#index' do
    let(:request_id) { '8a4886886e4c8e22016e5bee49c30007' }
    let(:get_messages) do
      VCR.use_cassette('appointment_request_messages/get_messages', match_requests_on: %i[method uri]) do
        get "/mobile/v0/appointment_requests/#{request_id}/messages",
            headers: iam_headers, params: { appointment_request_id: request_id }
      end
    end

    it 'returns 200 with message details upon success' do
      get_messages

      expected_message_body = {
        'data' => [
          {
            'id' => '8a4886886e4c8e22016e5bee49c30007',
            'type' => 'messages',
            'attributes' => {
              'messageText' => 'Testing',
              'messageDateTime' => '11/11/2019 12:26:13',
              'appointmentRequestId' => '8a4886886e4c8e22016e5bee49c30007',
              'date' => '2019-11-11T12:26:13.931+0000'
            }
          }
        ]
      }
      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(expected_message_body)
    end

    it 'matches the expected schema' do
      get_messages
      expect(response.body).to match_json_schema('appointment_request_messages')
    end

    it 'returns 200 when the upstream service returns an empty response' do
      VCR.use_cassette('appointment_request_messages/get_messages_unparsable', match_requests_on: %i[method uri]) do
        get "/mobile/v0/appointment_requests/#{request_id}/messages",
            headers: iam_headers, params: { appointment_request_id: request_id }
      end
      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq({ 'data' => [] })
    end

    it 'returns 502 when the upstream service returns 500' do
      VCR.use_cassette('appointment_request_messages/get_messages_500', match_requests_on: %i[method uri]) do
        get "/mobile/v0/appointment_requests/#{request_id}/messages",
            headers: iam_headers, params: { appointment_request_id: request_id }
      end
      expect(response.status).to eq(502)
      expect(response.parsed_body['errors'][0]['detail']).to \
        eq('Received an an invalid response from the upstream server')
    end
  end
end
