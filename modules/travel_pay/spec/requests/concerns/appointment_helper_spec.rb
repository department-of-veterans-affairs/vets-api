# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppointmentHelper do
  # Dummy class to test the concern
  let(:dummy_class) do
    Class.new do
      include AppointmentHelper
      attr_accessor :appts_service
    end
  end

  let(:instance) { dummy_class.new }
  let(:appointment_id) { 'aa0f63e0-5fa7-4d74-a17a-a6f510dbf69e' }
  let(:params) { { 'appointment_date_time' => '2025-01-01T10:00:00Z' } }

  describe '#find_or_create_appt_id!' do
    context 'when appts_service returns a valid appointment' do
      it 'returns the appointment id' do
        service_double = instance_double(TravelPay::AppointmentsService)
        allow(service_double).to receive(:find_or_create_appointment)
          .with(params)
          .and_return({ data: { 'id' => appointment_id } })

        instance.appts_service = service_double

        expect(instance.find_or_create_appt_id!('Complex', params)).to eq(appointment_id)
      end
    end

    context 'when appts_service returns nil' do
      it 'raises ResourceNotFound' do
        service_double = instance_double(TravelPay::AppointmentsService)
        allow(service_double).to receive(:find_or_create_appointment).and_return(nil)

        instance.appts_service = service_double

        expect { instance.find_or_create_appt_id!('Complex', params) }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::ResourceNotFound)
          expect(error.errors.first[:detail]).to eq("No appointment found for #{params['appointment_date_time']}")
        end
      end
    end

    context 'when appts_service returns empty data' do
      it 'raises ResourceNotFound' do
        service_double = instance_double(TravelPay::AppointmentsService)
        allow(service_double).to receive(:find_or_create_appointment)
          .with(params)
          .and_return({ data: nil })

        instance.appts_service = service_double

        expect { instance.find_or_create_appt_id!('Complex', params) }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::ResourceNotFound)
          expect(error.errors.first[:detail]).to eq("No appointment found for #{params['appointment_date_time']}")
        end
      end
    end
  end
end
