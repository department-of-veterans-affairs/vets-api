# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'

RSpec.describe VAOS::V2::AppointmentsController, type: :request do
  include ActiveSupport::Testing::TimeHelpers
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

    it 'returns :unprocessable_content for other errors' do
      expect(controller.send(:appointment_error_status, 'too-far-in-the-future')).to eq(:unprocessable_content)
      expect(controller.send(:appointment_error_status, 'already-canceled')).to eq(:unprocessable_content)
      expect(controller.send(:appointment_error_status, 'too-late-to-cancel')).to eq(:unprocessable_content)
      expect(controller.send(:appointment_error_status, 'unknown-error')).to eq(:unprocessable_content)
    end
  end

  describe '#appointment_facility_ids' do
    let(:controller) { described_class.new }

    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_oh_unique_user_metrics_logging_appt).and_return(true)
    end

    context 'when mhv_oh_unique_user_metrics_logging_appt feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_oh_unique_user_metrics_logging_appt).and_return(false)
      end

      it 'returns nil regardless of appointments' do
        appointments = [
          { location_id: '983', future: true, past: false, pending: false, status: 'booked' },
          { location_id: '984', future: false, past: true, pending: false, status: 'booked' }
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to be_nil
      end
    end

    context 'when appointments are visible (pending or non-cancelled with date flags)' do
      it 'returns unique facility IDs from visible appointments' do
        appointments = [
          { location_id: '983', future: true, past: false, pending: false, status: 'booked' },
          { location_id: '984', future: false, past: true, pending: false, status: 'booked' },
          { location_id: '757', future: false, past: false, pending: true, status: 'proposed' }
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to contain_exactly('983', '984', '757')
      end

      it 'extracts 3-character station ID from sta6aid format' do
        appointments = [
          { location_id: '983GC', future: true, past: false, pending: false, status: 'booked' },
          { location_id: '984HK', future: false, past: true, pending: false, status: 'booked' }
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to contain_exactly('983', '984')
      end

      it 'returns unique facility IDs when duplicates exist' do
        appointments = [
          { location_id: '983', future: true, past: false, pending: false, status: 'booked' },
          { location_id: '983GC', future: false, past: true, pending: false, status: 'booked' },
          { location_id: '983HK', future: false, past: false, pending: true, status: 'proposed' }
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to eq(['983'])
      end
    end

    context 'when appointments are cancelled' do
      it 'excludes cancelled appointments even if they have date flags' do
        appointments = [
          { location_id: '983', future: true, past: false, pending: false, status: 'cancelled' },
          { location_id: '984', future: false, past: true, pending: false, status: 'cancelled' }
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to be_nil
      end

      it 'includes pending appointments even if status is cancelled' do
        # Pending appointments are always visible regardless of status
        appointments = [
          { location_id: '983', future: false, past: false, pending: true, status: 'cancelled' },
          { location_id: '984', future: true, past: false, pending: false, status: 'cancelled' }
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to eq(['983'])
      end
    end

    context 'when appointments have no visibility flags set' do
      it 'returns nil when all appointments lack date flags' do
        appointments = [
          { location_id: '983', future: false, past: false, pending: false, status: 'booked' },
          { location_id: '984', future: false, past: false, pending: false, status: 'booked' }
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to be_nil
      end
    end

    context 'when appointments list is empty' do
      it 'returns nil' do
        result = controller.send(:appointment_facility_ids, [])
        expect(result).to be_nil
      end
    end

    context 'when appointments have nil location_id' do
      it 'filters out appointments with nil location_id' do
        appointments = [
          { location_id: nil, future: true, past: false, pending: false, status: 'booked' },
          { location_id: '984', future: true, past: false, pending: false, status: 'booked' }
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to eq(['984'])
      end

      it 'returns nil when all visible appointments have nil location_id' do
        appointments = [
          { location_id: nil, future: true, past: false, pending: false, status: 'booked' },
          { location_id: nil, future: false, past: true, pending: false, status: 'booked' }
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to be_nil
      end
    end

    context 'with mixed visible and cancelled appointments' do
      it 'only includes facility IDs from visible non-cancelled appointments' do
        appointments = [
          { location_id: '983', future: true, past: false, pending: false, status: 'booked' }, # visible
          { location_id: '984', future: true, past: false, pending: false, status: 'cancelled' }, # cancelled
          { location_id: '757', future: false, past: false, pending: true, status: 'proposed' }   # visible (pending)
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to contain_exactly('983', '757')
      end
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
    let(:submit_params) do
      ActionController::Parameters.new(
        id: '123',
        referral_number: 'REF123',
        network_id: 'NET123',
        provider_service_id: 'PROV123',
        slot_id: 'SLOT123'
      )
    end

    before do
      allow(controller).to receive_messages(submit_params:)
      allow(controller).to receive(:render)
      allow(StatsD).to receive(:increment)
      allow(StatsD).to receive(:histogram)
    end

    context 'when appointment creation succeeds' do
      let(:current_user) { OpenStruct.new(icn: '123V456') }
      let(:result) do
        instance_double(VAOS::V2::CommunityCare::SubmitAppointment,
                        error: nil, appointment: OpenStruct.new(id: 'APPT123'))
      end

      before do
        allow(controller).to receive(:current_user).and_return(current_user)
        allow(VAOS::V2::CommunityCare::SubmitAppointment).to receive(:call).and_return(result)
      end

      it 'renders created status with appointment id' do
        controller.submit_referral_appointment

        expect(controller).to have_received(:render).with(
          json: { data: { id: 'APPT123' } },
          status: :created
        )
      end
    end

    context 'when appointment has an error field' do
      let(:current_user) { OpenStruct.new(icn: '123V456') }
      let(:result) do
        instance_double(VAOS::V2::CommunityCare::SubmitAppointment,
                        error: 'conflict', error_code: 'conflict')
      end

      before do
        allow(controller).to receive_messages(current_user:,
                                              submission_error_response: { errors: [{ detail: 'Error' }] })
        allow(VAOS::V2::CommunityCare::SubmitAppointment).to receive(:call).and_return(result)
      end

      it 'renders conflict status with error response' do
        controller.submit_referral_appointment

        expect(controller).to have_received(:render).with(
          json: { errors: [{ detail: 'Error' }] },
          status: :conflict
        )
      end
    end

    context 'when an exception is raised' do
      let(:error) { StandardError.new('Service unavailable') }
      let(:current_user) { OpenStruct.new(icn: '123V456') }

      before do
        allow(controller).to receive(:current_user).and_return(current_user)
        allow(controller).to receive(:handle_appointment_creation_error)
        allow(VAOS::V2::CommunityCare::SubmitAppointment).to receive(:call).and_raise(error)
      end

      it 'calls handle_appointment_creation_error' do
        controller.submit_referral_appointment

        expect(controller).to have_received(:handle_appointment_creation_error).with(error)
      end
    end
  end
end
