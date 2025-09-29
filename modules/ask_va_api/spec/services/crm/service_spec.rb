# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::Service do
  let(:icn) { '123' }
  let(:mock_data) do
    {
      data: [
        {
          respond_reply_id: 'Original Question',
          inquiryNumber: 'A-1',
          inquiryTopic: 'Topic',
          inquiryProcessingStatus: 'Close',
          lastUpdate: '08/07/23',
          submitterQuestions: 'When is Sergeant Joe Smith birthday?',
          attachments: [{ activity: 'activity_1', date_sent: '08/7/23' }],
          icn: '0001740097'
        }
      ]
    }
  end
  let(:service) { described_class.new(icn:) }
  let(:endpoint) { 'inquiries' }

  def mock_response(status:, body:)
    instance_double(Faraday::Response, status:, body: body.to_json)
  end

  shared_examples 'crm request with header' do |env, flag_state, expected_org|
    let(:response) { mock_response(status: 200, body: mock_data) }

    before do
      allow(Settings).to receive(:vsp_environment).and_return(env)
      allow(Flipper).to receive(:enabled?).with(:ask_va_api_patsr_separation).and_return(flag_state)
      allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')

      allow_any_instance_of(Faraday::Connection).to receive(:get).with(
        'eis/vagov.lob.ava/api/inquiries',
        organizationName: expected_org
      ) do |_, _, &block|
        request = double('request')
        expect(request).to receive(:headers=).with(hash_including('X-VA-ICN' => icn))
        block.call(request)
        response
      end
    end

    it "sends ICN header and returns parsed response in #{env} env" do
      res = JSON.parse(response.body, symbolize_names: true)
      expect(service.call(endpoint:)[:data].first).to eq(res[:data].first)
    end
  end

  # Legacy endpoints (flag disabled)
  include_examples 'crm request with header', 'development', false, 'iris-dev'
  include_examples 'crm request with header', 'test', false, 'iris-dev'
  include_examples 'crm request with header', 'staging', false, 'ava-qa'
  include_examples 'crm request with header', 'production', false, 'veft'

  # New endpoints (flag enabled)
  include_examples 'crm request with header', 'development', true, 'iris-dev'
  include_examples 'crm request with header', 'test', true, 'iris-dev'
  include_examples 'crm request with header', 'staging', true, 'ava-preprod'
  include_examples 'crm request with header', 'production', true, 'ava'

  describe 'api_end_to_end_testing' do
    let(:response) { mock_response(status: 200, body: mock_data) }

    before do
      allow(Settings).to receive(:vsp_environment).and_return('staging')
      allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')

      # Capture the request
      @captured_request = nil
      allow_any_instance_of(Faraday::Connection).to receive(:get) do |_, url, params, _|
        @captured_request = { url: url, params: params }
        response
      end
    end

    context 'when the feature toggle is enabled' do
      it 'sends ICN header and returns parsed response with correct organizationName' do
        allow(Flipper).to receive(:enabled?).with(:ask_va_api_preprod_for_end_to_end_testing).and_return(true)
        response = service.call(endpoint:)

        # Check captured request
        expect(@captured_request[:params]).to include({ organizationName: 'ava-preprod' })
      end
    end

    context 'when the feature toggle is disabled' do
      it 'sends ICN header and returns parsed response with correct organizationName' do
        allow(Flipper).to receive(:enabled?).with(:ask_va_api_preprod_for_end_to_end_testing).and_return(false)
        service.call(endpoint:)

        # Check captured request
        expect(@captured_request[:params]).to include({ organizationName: 'ava-qa' })
      end
    end
  end

  describe '#call' do
    context 'when the server returns an error' do
      let(:resp) { mock_response(body: { error: 'server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow(Settings).to receive(:vsp_environment).and_return('development')
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')

        allow_any_instance_of(Faraday::Connection).to receive(:get).with(
          'eis/vagov.lob.ava/api/inquiries',
          { organizationName: 'iris-dev' }
        ).and_raise(exception)
      end

      it 'returns an error response with matching status' do
        response = service.call(endpoint:)
        expect(response.status).to eq(resp.status)
      end
    end

    context 'when X-VA-ICN header is missing' do
      let(:error_body) { { Message: 'Missing required header: X-VA-ICN' } }
      let(:resp) { mock_response(status: 400, body: error_body) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow(Settings).to receive(:vsp_environment).and_return('development')
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')

        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(exception)
      end

      it 'raises an error when ICN header is missing' do
        response = service.call(endpoint:)
        expect(response.status).to eq(400)
        expect(response.body).to include('Missing required header')
      end
    end

    context 'when ICN is empty while retrieving by Inquiry Number' do
      let(:service) { described_class.new(icn: '') }
      let(:error_body) do
        { Message: 'Submitter ICN header value cannot be empty if retrieving by Inquiry Number' }
      end
      let(:resp) { mock_response(status: 400, body: error_body) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')

        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(exception)
      end

      it 'raises an error for empty ICN with inquiry number search' do
        response = service.call(endpoint:, payload: { inquiryNumber: 'A-20250221-05679' })
        expect(response.status).to eq(400)
        expect(response.body).to include('ICN header value cannot be empty')
      end
    end

    context 'when inquiry does not belong to the user' do
      let(:mock_success_body) do
        {
          Data: [],
          Message: nil,
          ExceptionOccurred: false,
          ExceptionMessage: nil,
          MessageId: 'e6e69752-6a20-4ba3-a437-90eb67e8b127'
        }
      end
      let(:response) { mock_response(status: 200, body: mock_success_body) }

      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')

        allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(response)
      end

      it 'returns an empty data array if inquiry does not belong to the user' do
        res = service.call(endpoint:, payload: { inquiryNumber: 'A-20250221-05679' })
        expect(res[:Data]).to eq([])
        expect(res[:MessageId]).to eq('e6e69752-6a20-4ba3-a437-90eb67e8b127')
      end
    end
  end
end
