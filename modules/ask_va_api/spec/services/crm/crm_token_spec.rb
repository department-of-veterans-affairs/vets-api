# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::CrmToken do
  let(:service) { described_class.new }

  def mock_response(status:, body:)
    instance_double(Faraday::Response, status:, body: body.to_json)
  end

  describe '#call' do
    context 'when veis auth service returns a success response' do
      let(:token_response) do
        {
          token_type: 'Bearer',
          expires_in: 3599,
          ext_expires_in: 3599,
          access_token: 'testtoken'
        }
      end
      let(:veis_token_response) { mock_response(body: token_response, status: 200) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(veis_token_response)
      end

      it 'returns token' do
        expect(service.call).to eq(token_response[:access_token])
      end
    end

    context 'when veis auth service returns a 401 error response' do
      let(:resp) { mock_response(body: { error: 'invalid_client' }, status: 401) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and raises exception' do
        expect { service.call }.to raise_exception(exception)
      end
    end
  end
end
