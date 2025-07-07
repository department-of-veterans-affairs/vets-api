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
      allow(StatsD).to receive(:measure)
      allow(Rails.logger).to receive(:info)
    end

    context 'when appointment creation succeeds' do
      let(:appointment) { OpenStruct.new(id: 'APPT123') }
      let(:current_user) { OpenStruct.new(icn: '123V456') }
      let(:ccra_referral_service) { instance_double(Ccra::ReferralService) }

      before do
        allow(eps_appointment_service).to receive(:submit_appointment).and_return(appointment)
        allow(controller).to receive_messages(current_user:, ccra_referral_service:)
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
            tags: ['Community Care Appointments']
          )
          expect(StatsD).to have_received(:measure).with(
            described_class::APPT_CREATION_DURATION_METRIC,
            5000,
            tags: ['Community Care Appointments']
          )
        end
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
        expect(StatsD).to have_received(:increment).with(
          described_class::APPT_CREATION_FAILURE_METRIC,
          tags: ['Community Care Appointments', 'error_type:conflict']
        )
      end
    end

    context 'when an exception is raised' do
      let(:error) { StandardError.new('Service unavailable') }

      before do
        allow(eps_appointment_service).to receive(:submit_appointment).and_raise(error)
        allow(controller).to receive(:handle_appointment_creation_error)
      end

      it 'calls handle_appointment_creation_error' do
        controller.submit_referral_appointment

        expect(controller).to have_received(:handle_appointment_creation_error).with(error)
        expect(StatsD).to have_received(:increment).with(
          described_class::APPT_CREATION_FAILURE_METRIC,
          tags: ['Community Care Appointments']
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

  describe '#get_provider_appointment_type_id' do
    let(:controller) { described_class.new }

    context 'when provider has no appointment types' do
      let(:provider) { OpenStruct.new(appointment_types: nil) }

      it 'raises BackendServiceException with appropriate error message' do
        expect do
          controller.send(:get_provider_appointment_type_id, provider)
        end.to raise_error(Common::Exceptions::BackendServiceException) { |e|
          expect(e).to have_attributes(
            key: 'PROVIDER_APPOINTMENT_TYPES_MISSING',
            original_status: 502,
            original_body: 'Provider appointment types data is not available'
          )
        }
      end
    end

    context 'when provider has empty appointment types array' do
      let(:provider) { OpenStruct.new(appointment_types: []) }

      it 'raises BackendServiceException with appropriate error message' do
        expect do
          controller.send(:get_provider_appointment_type_id, provider)
        end.to raise_error(Common::Exceptions::BackendServiceException) { |e|
          expect(e).to have_attributes(
            key: 'PROVIDER_APPOINTMENT_TYPES_MISSING',
            original_status: 502,
            original_body: 'Provider appointment types data is not available'
          )
        }
      end
    end

    context 'when provider has appointment types but none are self-schedulable' do
      let(:provider) do
        OpenStruct.new(
          appointment_types: [
            { id: '1', is_self_schedulable: false },
            { id: '2' }, # missing is_self_schedulable property
            { id: '3', is_self_schedulable: nil }
          ]
        )
      end

      it 'raises BackendServiceException with appropriate error message' do
        expect do
          controller.send(:get_provider_appointment_type_id, provider)
        end.to raise_error(Common::Exceptions::BackendServiceException) { |e|
          expect(e).to have_attributes(
            key: 'PROVIDER_SELF_SCHEDULABLE_TYPES_MISSING',
            original_status: 502,
            original_body: 'No self-schedulable appointment types available for this provider'
          )
        }
      end
    end

    context 'when provider has self-schedulable appointment types' do
      let(:provider) do
        OpenStruct.new(
          appointment_types: [
            { id: '1', is_self_schedulable: false },
            { id: '2', is_self_schedulable: true },
            { id: '3', is_self_schedulable: true }
          ]
        )
      end

      it 'returns the ID of the first self-schedulable appointment type' do
        result = controller.send(:get_provider_appointment_type_id, provider)
        expect(result).to eq('2')
      end
    end

    context 'when provider has mixed appointment types with different is_self_schedulable values' do
      let(:provider) do
        OpenStruct.new(
          appointment_types: [
            { id: '1' }, # missing property
            { id: '2', is_self_schedulable: nil },
            { id: '3', is_self_schedulable: false },
            { id: '4', is_self_schedulable: true },
            { id: '5', is_self_schedulable: true }
          ]
        )
      end

      it 'returns the ID of the first appointment type where is_self_schedulable is explicitly true' do
        result = controller.send(:get_provider_appointment_type_id, provider)
        expect(result).to eq('4')
      end
    end
  end

  describe '#fetch_provider_slots' do
    let(:controller) { described_class.new }
    let(:eps_provider_service) { instance_double(Eps::ProviderService) }
    let(:referral) do
      OpenStruct.new(
        referral_date: '2024-01-01',
        expiration_date: '2024-12-31'
      )
    end
    let(:provider) do
      OpenStruct.new(
        id: 'provider123',
        appointment_types: [{ id: 'type123', is_self_schedulable: true }]
      )
    end

    before do
      allow(controller).to receive(:eps_provider_service).and_return(eps_provider_service)
    end

    context 'when provider has valid self-schedulable appointment types' do
      let(:expected_slots) { [{ id: 'slot1' }, { id: 'slot2' }] }

      before do
        allow(eps_provider_service).to receive(:get_provider_slots).and_return(expected_slots)
      end

      context 'when referral date is in the past' do
        before do
          travel_to Date.parse('2024-06-15')
        end

        after do
          travel_back
        end

        it 'uses current date instead of past referral date for startOnOrAfter' do
          result = controller.send(:fetch_provider_slots, referral, provider)

          expect(eps_provider_service).to have_received(:get_provider_slots).with(
            'provider123',
            hash_including(
              appointmentTypeId: 'type123',
              startOnOrAfter: '2024-06-15T00:00:00Z',
              startBefore: '2024-12-31T00:00:00Z'
            )
          )
          expect(result).to eq(expected_slots)
        end
      end

      context 'when referral date is in the future' do
        let(:referral) do
          OpenStruct.new(
            referral_date: '2024-08-01',
            expiration_date: '2024-12-31'
          )
        end

        before do
          travel_to Date.parse('2024-06-15')
        end

        after do
          travel_back
        end

        it 'uses future referral date for startOnOrAfter' do
          result = controller.send(:fetch_provider_slots, referral, provider)

          expect(eps_provider_service).to have_received(:get_provider_slots).with(
            'provider123',
            hash_including(
              appointmentTypeId: 'type123',
              startOnOrAfter: '2024-08-01T00:00:00Z',
              startBefore: '2024-12-31T00:00:00Z'
            )
          )
          expect(result).to eq(expected_slots)
        end
      end
    end

    context 'when provider has no self-schedulable appointment types' do
      let(:provider) do
        OpenStruct.new(
          id: 'provider123',
          appointment_types: [{ id: 'type123', is_self_schedulable: false }]
        )
      end

      before do
        allow(eps_provider_service).to receive(:get_provider_slots)
      end

      it 'raises BackendServiceException before calling get_provider_slots' do
        expect do
          controller.send(:fetch_provider_slots, referral, provider)
        end.to raise_error(Common::Exceptions::BackendServiceException) { |e|
          expect(e).to have_attributes(
            key: 'PROVIDER_SELF_SCHEDULABLE_TYPES_MISSING'
          )
        }

        expect(eps_provider_service).not_to have_received(:get_provider_slots)
      end
    end

    context 'when date parsing raises ArgumentError' do
      let(:referral) do
        OpenStruct.new(
          referral_date: 'invalid-date',
          expiration_date: '2024-12-31'
        )
      end

      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and returns nil' do
        result = controller.send(:fetch_provider_slots, referral, provider)

        expect(Rails.logger).to have_received(:error).with('Community Care Appointments: Error fetching provider slots')
        expect(result).to be_nil
      end
    end
  end
end
