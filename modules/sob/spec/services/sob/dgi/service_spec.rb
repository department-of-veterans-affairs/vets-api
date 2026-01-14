# frozen_string_literal: true

require 'rails_helper'
require 'timecop'

RSpec.describe SOB::DGI::Service do
  let(:service) { described_class.new(ssn:) }

  describe '#initialize' do
    let(:ssn) { '374374377' }

    it 'assigns SSN value if present' do
      expect(service.instance_variable_get(:@ssn)).to eq(ssn)
    end

    it 'raises error if ssn missing' do
      expect { described_class.new(ssn: nil) }.to raise_error(Common::Exceptions::ParameterMissing)
    end
  end

  describe '#get_ch33_status' do
    let(:ssn) { '374374377' }
    let(:body) { nil }
    let(:raw_response) { instance_double(Faraday::Response, status: 200, body:) }
    let(:response) { instance_double(SOB::DGI::Response) }
    let(:jwt) { 'TOKEN123' }
    let(:headers) { { Authorization: "Bearer #{jwt}" } }
    let(:payload) do
      { ssn:,
        benefitType: described_class::BENEFIT_TYPE,
        enrollment: 'NO' }
    end
    let(:request_params) { [:post, 'claimants', payload.to_json, headers] }

    before do
      allow(SOB::AuthenticationTokenService).to(receive(:call)).and_return(jwt)
      allow(service).to receive(:perform).with(*request_params).and_return(raw_response)
      allow(SOB::DGI::Response).to receive(:new)
        .with(raw_response.status, raw_response)
        .and_return(response)
      allow(Rails.logger).to receive(:error)
    end

    context 'when successful' do
      it 'sends payload with ssn to DGI' do
        service.get_ch33_status
        expect(service).to have_received(:perform).with(*request_params)
        expect(SOB::DGI::Response).to have_received(:new)
          .with(raw_response.status, raw_response)
      end
    end

    shared_context 'unsuccessful request' do
      let(:error_klass) { Common::Exceptions::BackendServiceException }
      let(:current_time) { Timecop.freeze(Time.zone.now) }
      let(:error) { error_klass.new(key, response_values, status) }
      let(:error_context) do
        { service: 'SOB/DGI',
          error_class: error.class.name,
          error_status: error.original_status,
          timestamp: Time.current.iso8601 }
      end

      before { Timecop.freeze(current_time) }

      after { Timecop.return }
    end

    context 'when claimant not found' do
      include_context 'unsuccessful request'

      let(:body) { { 'status' => 204, 'claimant' => nil } }
      let(:key) { 'SOB_CH33_STATUS_404' }
      let(:status) { 404 }
      let(:response_values) { {} }

      before { allow(error_klass).to receive(:new).and_return(error) }

      it 'converts 204 to 404 and raises/logs error' do
        expect { service.get_ch33_status }.to raise_error(error)
        expect(Rails.logger).to have_received(:error).with(
          'SOB/DGI service error',
          error_context,
          backtrace: error.backtrace
        )
      end
    end

    context 'when 200 response but Ch. 33 data missing' do
      include_context 'unsuccessful request'

      let(:key) { 'SOB_CH33_STATUS_404' }
      let(:status) { 404 }
      let(:response_values) { {} }

      before do
        allow(SOB::DGI::Response).to receive(:new)
          .with(raw_response.status, raw_response)
          .and_raise(SOB::DGI::Response::Ch33DataMissing)
        allow(error_klass).to receive(:new).and_return(error)
      end

      it 'raises 404 and logs error' do
        expect { service.get_ch33_status }.to raise_error(error)
        expect(Rails.logger).to have_received(:error).with(
          'SOB/DGI service error',
          error_context,
          backtrace: error.backtrace
        )
      end
    end

    context 'when unsuccessful' do
      include_context 'unsuccessful request'
      let(:key) { 'SOB_CH33_STATUS_500' }
      let(:status) { 500 }
      let(:response_values) { { status:, detail: nil, code: key, source: nil } }

      before { allow(service).to receive(:perform).with(*request_params).and_raise(error) }

      it 'logs and raises error' do
        expect { service.get_ch33_status }.to raise_error(error)
        expect(Rails.logger).to have_received(:error).with(
          'SOB/DGI service error',
          error_context,
          backtrace: error.backtrace
        )
      end
    end
  end
end
