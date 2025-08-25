# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/invoice/service'

RSpec.describe Invoice::Service do
  let(:current_user) { create(:user, :with_terms_of_use_agreement) }
  let(:service)      { described_class.new(current_user) }

  describe '#get_invoice' do
    let(:endpoint) { 'invoices' }
    let(:response_body) { Rails.root.join('spec/fixtures/lighthouse_invoice/response.json').read }
    let(:faraday_response) { instance_double(Faraday::Response, body: response_body) }

    before do
      allow(service.send(:config).connection)
        .to receive(:get)
        .and_return(faraday_response)
    end

    it 'makes a GET request to the invoices endpoint with the correct parameters' do
      result = service.get_invoice

      expect(result).to eq(response_body)

      expect(service.send(:config).connection)
        .to have_received(:get)
        .with(endpoint, hash_including(icn: current_user.icn))
    end

    context 'when a ClientError is raised' do
      let(:error) { Common::Client::Errors::ClientError.new('Service error') }

      before do
        allow(service.send(:config).connection).to receive(:get).and_raise(error)
        allow(Lighthouse::ServiceException).to receive(:send_error)
        allow(service).to receive(:handle_error).and_call_original
      end

      it 'calls handle_error and re-raises the error' do
        expect { service.get_invoice }.to raise_error(Common::Client::Errors::ClientError)
        expect(service).to have_received(:handle_error).with(error, nil, endpoint)
      end
    end
  end
end
