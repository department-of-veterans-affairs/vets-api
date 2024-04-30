# frozen_string_literal: true

require 'rails_helper'

describe CheckIn::VAOS::FacilityService do
  subject { described_class }

  let(:facility_id) { '500' }

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build).to be_an_instance_of(described_class)
    end
  end

  describe '#perform' do
    let(:facility_response) do
      {
        id: '500',
        facilitiesApiId: 'vha_500',
        vistaSite: '500',
        vastParent: '500',
        type: 'va_health_facility',
        name: 'Johnson & Johnson',
        classification: 'MC',
        timezone: {
          timeZoneId: 'America/New_York'
        },
        lat: 32.78447,
        long: -79.95415,
        phone: {
          main: '123-456-7890',
          fax: '456-892-7890',
          pharmacy: '632-456-6734',
          afterHours: '642-632-8932'
        }
      }.to_json
    end
    let(:faraday_response) { double('Faraday::Response') }
    let(:faraday_env) { double('Faraday::Env', status: 200, body: facility_response) }

    context 'when vaos returns successful response' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get)
          .with("/facilities/v2/facilities/#{facility_id}",
                {})
          .and_return(faraday_response)
        allow(faraday_response).to receive(:env).and_return(faraday_env)
      end

      it 'returns facility' do
        svc = subject.build(facility_id:)
        response = svc.get_facility
        expect(response.status).to eq(200)
        expect(response.body).to eq(facility_response)
      end
    end

    context 'when facilities api return server error' do
      let(:resp) { Faraday::Response.new(body: { error: 'Internal server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(exception)
      end

      it 'throws exception' do
        svc = subject.build(facility_id:)
        expect do
          svc.get_facility
        end.to(raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BackendServiceException)
        end)
      end
    end
  end
end
