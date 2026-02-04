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

    it 'returns :unprocessable_entity for other errors' do
      expect(controller.send(:appointment_error_status, 'too-far-in-the-future')).to eq(:unprocessable_entity)
      expect(controller.send(:appointment_error_status, 'already-canceled')).to eq(:unprocessable_entity)
      expect(controller.send(:appointment_error_status, 'too-late-to-cancel')).to eq(:unprocessable_entity)
      expect(controller.send(:appointment_error_status, 'unknown-error')).to eq(:unprocessable_entity)
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
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

    before do
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear

      allow(controller).to receive_messages(
        eps_appointment_service:,
        submit_params:,
        patient_attributes: {}
      )
      allow(controller).to receive(:render)
      allow(StatsD).to receive(:increment)
      allow(StatsD).to receive(:histogram)
      allow(Rails.logger).to receive(:info)
    end

    context 'when appointment creation succeeds' do
      let(:appointment) { OpenStruct.new(id: 'APPT123') }
      let(:current_user) { OpenStruct.new(icn: '123V456') }
      let(:ccra_referral_service) { instance_double(Ccra::ReferralService) }

      before do
        allow(eps_appointment_service).to receive(:submit_appointment).and_return(appointment)
        allow(controller).to receive_messages(current_user:, ccra_referral_service:)
        allow(ccra_referral_service).to receive(:get_cached_referral_data).and_return(nil)
      end

      it 'renders created status with appointment id and logs duration' do
        Timecop.freeze(Time.current) do
          booking_start_time = Time.current.to_f - 5
          allow(ccra_referral_service).to receive(:get_booking_start_time)
            .with(submit_params[:referral_number], current_user.icn)
            .and_return(booking_start_time)

          controller.submit_referral_appointment

          expect(controller).to have_received(:render).with(
            json: { data: { id: 'APPT123' } },
            status: :created
          )
          expect(StatsD).to have_received(:increment).with(
            described_class::APPT_CREATION_SUCCESS_METRIC,
            tags: ['service:community_care_appointments', 'type_of_care:no_value']
          )
          expect(StatsD).to have_received(:histogram).with(
            described_class::APPT_CREATION_DURATION_METRIC,
            5000,
            tags: ['service:community_care_appointments']
          )
        end
      end
    end

    context 'when appointment has an error field' do
      let(:appointment) { { error: 'conflict' } }
      let(:current_user) { OpenStruct.new(icn: '123V456') }
      let(:ccra_referral_service) { instance_double(Ccra::ReferralService) }

      before do
        allow(eps_appointment_service).to receive(:submit_appointment).and_return(appointment)
        allow(controller).to receive(:submission_error_response).and_return({ errors: [{ detail: 'Error' }] })
        allow(controller).to receive_messages(current_user:, ccra_referral_service:)
        allow(ccra_referral_service).to receive(:get_cached_referral_data).and_return(nil)
      end

      it 'renders conflict status with error response' do
        controller.submit_referral_appointment

        expect(controller).to have_received(:render).with(
          json: { errors: [{ detail: 'Error' }] },
          status: :conflict
        )
        expect(StatsD).to have_received(:increment).with(
          described_class::APPT_CREATION_FAILURE_METRIC,
          tags: ['service:community_care_appointments', 'type_of_care:no_value']
        )
      end
    end

    context 'when an exception is raised' do
      let(:error) { StandardError.new('Service unavailable') }
      let(:current_user) { OpenStruct.new(icn: '123V456') }
      let(:ccra_referral_service) { instance_double(Ccra::ReferralService) }

      before do
        allow(eps_appointment_service).to receive(:submit_appointment).and_raise(error)
        allow(controller).to receive(:handle_appointment_creation_error)
        allow(controller).to receive_messages(current_user:, ccra_referral_service:)
        allow(ccra_referral_service).to receive(:get_cached_referral_data).and_return(nil)
      end

      it 'calls handle_appointment_creation_error' do
        controller.submit_referral_appointment

        expect(controller).to have_received(:handle_appointment_creation_error).with(error)
        expect(StatsD).to have_received(:increment).with(
          described_class::APPT_CREATION_FAILURE_METRIC,
          tags: ['service:community_care_appointments', 'type_of_care:no_value']
        )
      end
    end

    context 'when patient attributes are empty' do
      let(:appointment) { OpenStruct.new(id: 'APPT123') }

      before do
        allow(eps_appointment_service).to receive(:submit_appointment).and_return(appointment)
        allow(controller).to receive(:patient_attributes).and_return({})
      end

      it 'does not include additional_patient_attributes in the service call' do
        controller.submit_referral_appointment

        expect(eps_appointment_service).to have_received(:submit_appointment).with(
          submit_params[:id],
          {
            referral_number: submit_params[:referral_number],
            network_id: submit_params[:network_id],
            provider_service_id: submit_params[:provider_service_id],
            slot_ids: [submit_params[:slot_id]]
          }
        )
      end
    end
  end
end
