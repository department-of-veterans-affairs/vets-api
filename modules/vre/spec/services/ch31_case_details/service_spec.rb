# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VRE::Ch31CaseDetails::Service do
  let(:service) { described_class.new(icn) }
  let(:icn) { '1012667145V762142' }
  let(:error_klass) { Common::Exceptions::BackendServiceException }

  describe '#initialize' do
    it 'assigns ICN value if present' do
      expect(service.instance_variable_get(:@icn)).to eq(icn)
    end

    it 'raises error if icn missing' do
      expect { described_class.new(nil) }.to raise_error(Common::Exceptions::ParameterMissing)
    end
  end

  describe '#get_details' do
    let(:raw_response) { instance_double(Faraday::Response, status: 200) }
    let(:response) { instance_double(VRE::Ch31CaseDetails::Response) }
    let(:url) { "#{Settings.res.base_url}/suite/webapi/get-ch31-case-details" }
    let(:headers) { { 'Appian-API-Key' => Settings.res.api_key } }
    let(:request_params) { [:post, url, { icn: }.to_json, headers] }

    context 'when successful' do
      it 'sends payload with icn to RES' do
        allow(service).to receive(:perform).with(*request_params).and_return(raw_response)
        allow(VRE::Ch31CaseDetails::Response).to receive(:new)
          .with(raw_response.status, raw_response)
          .and_return(response)
        service.get_details
        expect(service).to have_received(:perform).with(*request_params)
        expect(VRE::Ch31CaseDetails::Response).to have_received(:new)
          .with(raw_response.status, raw_response)
      end
    end

    context 'when unsuccessful' do
      let(:key) { 'RES_CH31_CASE_DETAILS_403' }
      let(:response_values) { { status: 403, detail: nil, code: key, source: nil } }
      let(:message) { 'Internal server error occurred while retrieving data from MPI.' }
      let(:error) { error_klass.new(key, response_values, 403, 'errorMessageList' => message) }

      before { allow(service).to receive(:send_to_res).and_raise(error) }

      it 'logs and raises error' do
        allow(Rails.logger).to receive(:error)
        expect { service.get_details }.to raise_error(error_klass)
        expect(Rails.logger).to have_received(:error)
          .with("Failed to retrieve Ch. 31 case details: #{message}", backtrace: error.backtrace)
      end
    end

    context 'when RES service unavailable' do
      let(:key) { 'RES_CH31_CASE_DETAILS_500' }
      let(:response_values) { { status: 500, detail: nil, code: key, source: nil } }
      let(:message) { described_class::SERVICE_UNAVAILABLE_ERROR }
      let(:error) { error_klass.new(key, response_values, 500, 'error' => message) }

      before do
        allow(service).to receive(:send_to_res).and_raise(error)
      end

      it 'logs and raises 503 error' do
        allow(Rails.logger).to receive(:error)
        expect { service.get_details }.to raise_error(error_klass) do |raised|
          expect(raised.key).to eq('RES_CH31_CASE_DETAILS_503')
        end
        expect(Rails.logger).to have_received(:error)
          .with("Failed to retrieve Ch. 31 case details: #{message}", backtrace: error.backtrace)
      end
    end
  end
end
