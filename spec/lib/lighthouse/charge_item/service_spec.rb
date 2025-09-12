# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/charge_item/service'
require 'lighthouse/service_exception'
require 'common/client/errors'

RSpec.describe ChargeItem::Service do
  let(:invoice_id)        { '12345' }
  let(:service)           { described_class.new(invoice_id) }
  let(:response_body)     { Rails.root.join('spec', 'fixtures', 'lighthouse_charge_item', 'response.json').read }
  let(:faraday_response)  { instance_double(Faraday::Response, body: response_body) }
  let(:expected_url)      { "#{service.send(:config).charge_item_url}/#{invoice_id}" }

  before do
    allow(service.send(:config).connection)
      .to receive(:get)
      .and_return(faraday_response)
  end

  describe '#get_charge_items' do
    it 'makes a GET request to the charge items endpoint with the correct parameters' do
      result = service.get_charge_items
      expect(result).to eq(response_body)

      expect(service.send(:config).connection)
        .to have_received(:get).with(expected_url)
    end

    context 'when a ClientError is raised' do
      let(:error) { Common::Client::Errors::ClientError.new('Service error') }

      before do
        allow(service.send(:config).connection).to receive(:get).and_raise(error)
        allow(Lighthouse::ServiceException).to receive(:send_error)
        allow(service).to receive(:handle_error).and_call_original
      end

      it 'calls handle_error and re-raises the error' do
        expect { service.get_charge_items }.to raise_error(Common::Client::Errors::ClientError)
        expect(service).to have_received(:handle_error).with(error, nil, expected_url)
      end
    end
  end
end
