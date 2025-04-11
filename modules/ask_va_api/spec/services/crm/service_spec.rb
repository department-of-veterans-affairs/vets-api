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

  shared_examples 'crm request with header' do |env, expected_org|
    let(:response) { mock_response(status: 200, body: mock_data) }

    before do
      allow(Settings).to receive(:vsp_environment).and_return(env)
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

  describe '#call' do
    include_examples 'crm request with header', 'development', 'iris-dev'
    include_examples 'crm request with header', 'test', 'iris-dev'
    include_examples 'crm request with header', 'staging', 'veft-preprod'
    include_examples 'crm request with header', 'production', 'veft'

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
  end
end
