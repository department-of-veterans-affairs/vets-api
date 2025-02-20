# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::Service do
  let(:service) { described_class.new(icn: '123') }

  def mock_response(status:, body:)
    instance_double(Faraday::Response, status:, body: body.to_json)
  end

  describe '#call' do
    let(:endpoint) { 'inquiries' }

    context 'when server response successful' do
      context 'with valid JSON' do
        let(:response) do
          mock_response(
            status: 200,
            body: {
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
          )
        end

        context 'when on local/dev env' do
          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
            allow_any_instance_of(Faraday::Connection).to receive(:get).with('eis/vagov.lob.ava/api/inquiries',
                                                                             icn: '123',
                                                                             organizationName: 'iris-dev')
                                                                       .and_return(response)
          end

          it 'returns a parsed response' do
            res = JSON.parse(response.body, symbolize_names: true)
            expect(service.call(endpoint:)[:data].first).to eq(res[:data].first)
          end
        end

        context 'when on staging env' do
          before do
            allow(Settings).to receive(:vsp_environment).and_return('staging')
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
            allow_any_instance_of(Faraday::Connection).to receive(:get).with('eis/vagov.lob.ava/api/inquiries',
                                                                             icn: '123',
                                                                             organizationName: 'veft-preprod')
                                                                       .and_return(response)
          end

          it 'returns a parsed response' do
            res = JSON.parse(response.body, symbolize_names: true)
            expect(service.call(endpoint:)[:data].first).to eq(res[:data].first)
          end
        end
      end
    end

    context 'when the server returns an error' do
      let(:resp) { mock_response(body: { error: 'server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow(Settings).to receive(:vsp_environment).and_return('development')
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
        allow_any_instance_of(Faraday::Connection).to receive(:get).with('eis/vagov.lob.ava/api/inquiries',
                                                                         { icn: '123',
                                                                           organizationName: 'iris-dev' })
                                                                   .and_raise(exception)
      end

      it 'raises a service error' do
        response = service.call(endpoint:)
        expect(response.status).to eq(resp.status)
      end
    end
  end
end
