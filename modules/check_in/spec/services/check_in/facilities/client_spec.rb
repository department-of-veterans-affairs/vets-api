# frozen_string_literal: true

require 'rails_helper'

describe CheckIn::Facilities::Client do
  subject { described_class.new }

  describe '.new' do
    it 'returns an instance of described_class' do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe '#facilities' do
    context 'when facilities service returns success response' do
      let(:facilities_response) do
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
        }
      end

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(facilities_response)
      end

      it 'returns appointments data' do
        expect(subject.facilities(facility_id: 500)).to eq(facilities_response)
      end
    end

    context 'when facilities service returns 404 error response' do
      let(:error_msg) do
        {
          code: 404,
          errorCode: 1007,
          traceId: 'test-trace-id',
          message: 'Unknown facility ID',
          detail: 'Facility not found when searching by ID: 0'
        }
      end
      let(:resp) { Faraday::Response.new(body: error_msg, status: 404) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(exception)
      end

      it 'returns 404 not found' do
        expect { subject.facilities(facility_id: 0) }.to raise_exception(exception)
      end
    end
  end
end
