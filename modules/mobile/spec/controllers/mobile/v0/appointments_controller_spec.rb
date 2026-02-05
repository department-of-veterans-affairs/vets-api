# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::AppointmentsController, type: :controller do
  describe '#appointment_facility_ids' do
    let(:controller) { described_class.new }
    let(:cancelled_status) { Mobile::V0::Adapters::VAOSV2Appointment::STATUSES[:cancelled] }
    let(:booked_status) { Mobile::V0::Adapters::VAOSV2Appointment::STATUSES[:booked] }

    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_oh_unique_user_metrics_logging_appt).and_return(true)
    end

    def mock_appointment(facility_id:, is_pending:, status:)
      instance_double(
        Mobile::V0::Appointment,
        facility_id:,
        is_pending:,
        status:
      )
    end

    context 'when mhv_oh_unique_user_metrics_logging_appt feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_oh_unique_user_metrics_logging_appt).and_return(false)
      end

      it 'returns nil regardless of appointments' do
        appointments = [
          mock_appointment(facility_id: '983', is_pending: false, status: booked_status),
          mock_appointment(facility_id: '984', is_pending: false, status: booked_status)
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to be_nil
      end
    end

    context 'when appointments are visible (pending or not cancelled)' do
      it 'returns unique facility IDs from visible appointments' do
        appointments = [
          mock_appointment(facility_id: '983', is_pending: false, status: booked_status),
          mock_appointment(facility_id: '984', is_pending: false, status: booked_status),
          mock_appointment(facility_id: '757', is_pending: true, status: booked_status)
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to contain_exactly('983', '984', '757')
      end

      it 'extracts 3-character station ID from sta6aid format' do
        appointments = [
          mock_appointment(facility_id: '983GC', is_pending: false, status: booked_status),
          mock_appointment(facility_id: '984HK', is_pending: false, status: booked_status)
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to contain_exactly('983', '984')
      end

      it 'returns unique facility IDs when duplicates exist' do
        appointments = [
          mock_appointment(facility_id: '983', is_pending: false, status: booked_status),
          mock_appointment(facility_id: '983GC', is_pending: false, status: booked_status),
          mock_appointment(facility_id: '983HK', is_pending: true, status: booked_status)
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to eq(['983'])
      end
    end

    context 'when appointments include pending appointments' do
      it 'includes pending appointments regardless of status' do
        appointments = [
          mock_appointment(facility_id: '983', is_pending: true, status: cancelled_status),
          mock_appointment(facility_id: '984', is_pending: true, status: booked_status)
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to contain_exactly('983', '984')
      end
    end

    context 'when all appointments are cancelled and not pending' do
      it 'returns nil' do
        appointments = [
          mock_appointment(facility_id: '983', is_pending: false, status: cancelled_status),
          mock_appointment(facility_id: '984', is_pending: false, status: cancelled_status)
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

    context 'when appointments have nil facility_id' do
      it 'filters out appointments with nil facility_id' do
        appointments = [
          mock_appointment(facility_id: nil, is_pending: false, status: booked_status),
          mock_appointment(facility_id: '984', is_pending: false, status: booked_status)
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to eq(['984'])
      end

      it 'returns nil when all visible appointments have nil facility_id' do
        appointments = [
          mock_appointment(facility_id: nil, is_pending: false, status: booked_status),
          mock_appointment(facility_id: nil, is_pending: true, status: booked_status)
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to be_nil
      end
    end

    context 'with mixed visible and cancelled appointments' do
      it 'only includes facility IDs from visible appointments' do
        appointments = [
          mock_appointment(facility_id: '983', is_pending: false, status: booked_status), # visible (booked)
          mock_appointment(facility_id: '984', is_pending: false, status: cancelled_status), # not visible (cancelled)
          mock_appointment(facility_id: '757', is_pending: true, status: cancelled_status)   # visible (pending)
        ]

        result = controller.send(:appointment_facility_ids, appointments)
        expect(result).to contain_exactly('983', '757')
      end
    end
  end
end
