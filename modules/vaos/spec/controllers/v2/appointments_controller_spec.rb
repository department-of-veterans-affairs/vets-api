# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'

RSpec.describe VAOS::V2::AppointmentsController, type: :request do
  describe '#start_date' do
    context 'with an invalid date' do
      it 'throws an InvalidFieldValue exception' do
        subject.params = { start: 'not a date', end: '2022-09-21T00:00:00+00:00' }

        expect do
          subject.send(:start_date)
        end.to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#end_date' do
    context 'with an invalid date' do
      it 'throws an InvalidFieldValue exception' do
        subject.params = { end: 'not a date', start: '2022-09-21T00:00:00+00:00' }

        expect do
          subject.send(:end_date)
        end.to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#appointment_error_status' do
    let(:controller) { described_class.new }

    it 'returns :conflict for conflict error' do
      expect(controller.send(:appointment_error_status, 'conflict')).to eq(:conflict)
    end

    it 'returns :bad_request for bad-request error' do
      expect(controller.send(:appointment_error_status, 'bad-request')).to eq(:bad_request)
    end

    it 'returns :bad_gateway for internal-error error' do
      expect(controller.send(:appointment_error_status, 'internal-error')).to eq(:bad_gateway)
    end

    it 'returns :unprocessable_entity for other errors' do
      expect(controller.send(:appointment_error_status, 'too-far-in-the-future')).to eq(:unprocessable_entity)
      expect(controller.send(:appointment_error_status, 'already-canceled')).to eq(:unprocessable_entity)
      expect(controller.send(:appointment_error_status, 'too-late-to-cancel')).to eq(:unprocessable_entity)
      expect(controller.send(:appointment_error_status, 'unknown-error')).to eq(:unprocessable_entity)
    end
  end

  describe '#submission_error_response' do
    let(:controller) { described_class.new }

    it 'returns a properly formatted error response with the error code' do
      error_code = 'test-error'
      response = controller.send(:submission_error_response, error_code)

      expect(response).to be_a(Hash)
      expect(response[:errors]).to be_an(Array)
      expect(response[:errors].first[:title]).to eq('Appointment submission failed')
      expect(response[:errors].first[:detail]).to eq("An error occurred: #{error_code}")
      expect(response[:errors].first[:code]).to eq(error_code)
    end
  end

  describe '#submit_referral_appointment' do
    let(:controller) { described_class.new }
    let(:eps_appointment_service) { instance_double(Eps::AppointmentService) }
    let(:submit_params) do
      {
        id: '123',
        referral_number: 'REF123',
        network_id: 'NET123',
        provider_service_id: 'PROV123',
        slot_id: 'SLOT123'
      }
    end

    before do
      allow(controller).to receive_messages(
        eps_appointment_service:,
        submit_params:,
        patient_attributes: {}
      )
      allow(controller).to receive(:render)
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:info)
    end

    context 'when appointment creation succeeds' do
      let(:appointment) { OpenStruct.new(id: 'APPT123') }

      before do
        allow(eps_appointment_service).to receive(:submit_appointment).and_return(appointment)
      end

      it 'renders created status with appointment id' do
        controller.submit_referral_appointment

        expect(controller).to have_received(:render).with(
          json: { data: { id: 'APPT123' } },
          status: :created
        )
        expect(StatsD).to have_received(:increment).with('api.vaos.appointment_creation.success')
      end
    end

    context 'when appointment has an error field' do
      let(:appointment) { { error: 'conflict' } }

      before do
        allow(eps_appointment_service).to receive(:submit_appointment).and_return(appointment)
        allow(controller).to receive(:submission_error_response).and_return({ errors: [{ detail: 'Error' }] })
      end

      it 'renders conflict status with error response' do
        controller.submit_referral_appointment

        expect(controller).to have_received(:render).with(
          json: { errors: [{ detail: 'Error' }] },
          status: :conflict
        )
        expect(StatsD).to have_received(:increment).with('api.vaos.appointment_creation.failure',
                                                         tags: ['error_type:conflict'])
      end
    end

    context 'when an exception is raised' do
      let(:error) { StandardError.new('Service unavailable') }

      before do
        allow(eps_appointment_service).to receive(:submit_appointment).and_raise(error)
        allow(controller).to receive(:handle_appointment_error)
      end

      it 'calls handle_appointment_error' do
        controller.submit_referral_appointment

        expect(controller).to have_received(:handle_appointment_error).with(error)
        expect(StatsD).to have_received(:increment).with('api.vaos.appointment_creation.failure')
      end
    end
  end
end
