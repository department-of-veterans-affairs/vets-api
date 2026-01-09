# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vass::AppointmentSerializer, type: :serializer do
  let(:appointment_id) { 'appt-123' }
  let(:veteran_id) { 'vet-456' }
  let(:start_utc) { '2026-01-15T14:00:00Z' }
  let(:end_utc) { '2026-01-15T14:30:00Z' }
  let(:cohort_start_utc) { '2026-01-01T00:00:00Z' }
  let(:cohort_end_utc) { '2026-01-31T23:59:59Z' }
  let(:time_start_utc) { '2026-01-16T10:00:00Z' }
  let(:time_end_utc) { '2026-01-16T10:30:00Z' }
  let(:selected_agent_skills) { %w[skill-1 skill-2] }
  let(:agent_nickname) { 'Dr. Smith' }
  let(:correlation_id) { 'corr-789' }

  describe '#serializable_hash' do
    context 'with a fully booked appointment' do
      let(:appointment) do
        Vass::Appointment.new(
          id: appointment_id,
          appointment_id:,
          veteran_id:,
          start_utc:,
          end_utc:,
          cohort_start_utc:,
          cohort_end_utc:,
          selected_agent_skills:,
          status: 'booked',
          capacity: 5,
          agent_nickname:,
          correlation_id:
        )
      end

      let(:serialized) { described_class.new(appointment).serializable_hash }
      let(:data) { serialized[:data] }
      let(:attributes) { data[:attributes] }

      it 'includes the correct id' do
        expect(data[:id]).to eq(appointment_id)
      end

      it 'includes the correct type' do
        expect(data[:type]).to eq(:appointment)
      end

      it 'includes appointment_id' do
        expect(attributes[:appointment_id]).to eq(appointment_id)
      end

      it 'includes veteran_id' do
        expect(attributes[:veteran_id]).to eq(veteran_id)
      end

      it 'includes start_utc' do
        expect(attributes[:start_utc]).to eq(start_utc)
      end

      it 'includes end_utc' do
        expect(attributes[:end_utc]).to eq(end_utc)
      end

      it 'includes cohort_start_utc' do
        expect(attributes[:cohort_start_utc]).to eq(cohort_start_utc)
      end

      it 'includes cohort_end_utc' do
        expect(attributes[:cohort_end_utc]).to eq(cohort_end_utc)
      end

      it 'includes selected_agent_skills' do
        expect(attributes[:selected_agent_skills]).to eq(selected_agent_skills)
      end

      it 'includes status' do
        expect(attributes[:status]).to eq('booked')
      end

      it 'includes capacity' do
        expect(attributes[:capacity]).to eq(5)
      end

      it 'includes agent_nickname' do
        expect(attributes[:agent_nickname]).to eq(agent_nickname)
      end

      it 'includes correlation_id' do
        expect(attributes[:correlation_id]).to eq(correlation_id)
      end

      it 'includes computed effective_start_utc' do
        expect(attributes[:effective_start_utc]).to eq(start_utc)
      end

      it 'includes computed effective_end_utc' do
        expect(attributes[:effective_end_utc]).to eq(end_utc)
      end

      it 'includes computed duration_minutes' do
        expect(attributes[:duration_minutes]).to eq(30)
      end

      it 'includes computed is_booked' do
        expect(attributes[:is_booked]).to be true
      end

      it 'includes computed has_capacity' do
        expect(attributes[:has_capacity]).to be true
      end

      it 'includes computed has_cohort' do
        expect(attributes[:has_cohort]).to be true
      end
    end

    context 'with an available time slot using time_start_utc/time_end_utc' do
      let(:appointment) do
        Vass::Appointment.new(
          id: 'slot-789',
          time_start_utc:,
          time_end_utc:,
          capacity: 3,
          status: 'available'
        )
      end

      let(:serialized) { described_class.new(appointment).serializable_hash }
      let(:data) { serialized[:data] }
      let(:attributes) { data[:attributes] }

      it 'includes the correct id' do
        expect(data[:id]).to eq('slot-789')
      end

      it 'includes the correct type' do
        expect(data[:type]).to eq(:appointment)
      end

      it 'includes nil appointment_id' do
        expect(attributes[:appointment_id]).to be_nil
      end

      it 'includes nil veteran_id' do
        expect(attributes[:veteran_id]).to be_nil
      end

      it 'includes nil start_utc' do
        expect(attributes[:start_utc]).to be_nil
      end

      it 'includes nil end_utc' do
        expect(attributes[:end_utc]).to be_nil
      end

      it 'includes time_start_utc' do
        expect(attributes[:time_start_utc]).to eq(time_start_utc)
      end

      it 'includes time_end_utc' do
        expect(attributes[:time_end_utc]).to eq(time_end_utc)
      end

      it 'includes effective_start_utc from time_start_utc' do
        expect(attributes[:effective_start_utc]).to eq(time_start_utc)
      end

      it 'includes effective_end_utc from time_end_utc' do
        expect(attributes[:effective_end_utc]).to eq(time_end_utc)
      end

      it 'includes status' do
        expect(attributes[:status]).to eq('available')
      end

      it 'includes capacity' do
        expect(attributes[:capacity]).to eq(3)
      end

      it 'includes computed duration_minutes' do
        expect(attributes[:duration_minutes]).to eq(30)
      end

      it 'computes is_booked as false (no start_utc/end_utc)' do
        expect(attributes[:is_booked]).to be false
      end

      it 'includes computed has_capacity' do
        expect(attributes[:has_capacity]).to be true
      end

      it 'computes has_cohort as false' do
        expect(attributes[:has_cohort]).to be false
      end
    end

    context 'with minimal appointment data' do
      let(:appointment) do
        Vass::Appointment.new(
          id: 'minimal-123',
          start_utc:,
          end_utc:
        )
      end

      let(:serialized) { described_class.new(appointment).serializable_hash }
      let(:data) { serialized[:data] }
      let(:attributes) { data[:attributes] }

      it 'includes the id' do
        expect(data[:id]).to eq('minimal-123')
      end

      it 'includes nil for optional attributes' do
        expect(attributes[:appointment_id]).to be_nil
        expect(attributes[:veteran_id]).to be_nil
        expect(attributes[:cohort_start_utc]).to be_nil
        expect(attributes[:cohort_end_utc]).to be_nil
        expect(attributes[:selected_agent_skills]).to be_nil
        expect(attributes[:status]).to be_nil
        expect(attributes[:capacity]).to be_nil
        expect(attributes[:agent_nickname]).to be_nil
        expect(attributes[:correlation_id]).to be_nil
      end

      it 'includes start_utc' do
        expect(attributes[:start_utc]).to eq(start_utc)
      end

      it 'includes end_utc' do
        expect(attributes[:end_utc]).to eq(end_utc)
      end

      it 'computes is_booked as true' do
        expect(attributes[:is_booked]).to be true
      end

      it 'computes has_capacity as false when capacity is nil' do
        expect(attributes[:has_capacity]).to be false
      end

      it 'computes has_cohort as false when cohort dates are nil' do
        expect(attributes[:has_cohort]).to be false
      end
    end

    context 'with multiple appointments' do
      let(:appointment1) do
        Vass::Appointment.new(
          id: 'appt-1',
          appointment_id: 'appt-1',
          veteran_id:,
          start_utc:,
          end_utc:,
          status: 'booked'
        )
      end

      let(:appointment2) do
        Vass::Appointment.new(
          id: 'appt-2',
          time_start_utc: '2026-01-16T14:00:00Z',
          time_end_utc: '2026-01-16T14:30:00Z',
          capacity: 5,
          status: 'available'
        )
      end

      let(:appointments) { [appointment1, appointment2] }
      let(:serialized) { described_class.new(appointments).serializable_hash }
      let(:data) { serialized[:data] }

      it 'returns an array of serialized appointments' do
        expect(data).to be_an(Array)
        expect(data.length).to eq(2)
      end

      it 'serializes first appointment correctly' do
        first = data.first
        expect(first[:id]).to eq('appt-1')
        expect(first[:type]).to eq(:appointment)
        expect(first[:attributes][:appointment_id]).to eq('appt-1')
        expect(first[:attributes][:status]).to eq('booked')
        expect(first[:attributes][:is_booked]).to be true
      end

      it 'serializes second appointment correctly' do
        second = data.last
        expect(second[:id]).to eq('appt-2')
        expect(second[:type]).to eq(:appointment)
        expect(second[:attributes][:capacity]).to eq(5)
        expect(second[:attributes][:status]).to eq('available')
        expect(second[:attributes][:is_booked]).to be false
      end
    end

    context 'JSON:API compliance' do
      let(:appointment) do
        Vass::Appointment.new(
          id: appointment_id,
          appointment_id:,
          veteran_id:,
          start_utc:,
          end_utc:
        )
      end

      let(:serialized) { described_class.new(appointment).serializable_hash }

      it 'has top-level data key' do
        expect(serialized).to have_key(:data)
      end

      it 'has id in data' do
        expect(serialized[:data]).to have_key(:id)
      end

      it 'has type in data' do
        expect(serialized[:data]).to have_key(:type)
      end

      it 'has attributes in data' do
        expect(serialized[:data]).to have_key(:attributes)
      end

      it 'does not include id in attributes' do
        expect(serialized[:data][:attributes]).not_to have_key(:id)
      end

      it 'does not include type in attributes' do
        expect(serialized[:data][:attributes]).not_to have_key(:type)
      end
    end

    context 'with computed attributes' do
      let(:appointment) do
        Vass::Appointment.new(
          id: appointment_id,
          start_utc: '2026-01-15T10:00:00Z',
          end_utc: '2026-01-15T11:00:00Z',
          capacity: 0
        )
      end

      let(:serialized) { described_class.new(appointment).serializable_hash }
      let(:attributes) { serialized[:data][:attributes] }

      it 'computes duration_minutes correctly for 60 minute appointment' do
        expect(attributes[:duration_minutes]).to eq(60)
      end

      it 'computes is_booked as true when times are present' do
        expect(attributes[:is_booked]).to be true
      end

      it 'computes has_capacity as false when capacity is zero' do
        expect(attributes[:has_capacity]).to be false
      end
    end

    context 'with nil computed attributes' do
      let(:appointment) do
        Vass::Appointment.new(
          id: appointment_id,
          appointment_id:
        )
      end

      let(:serialized) { described_class.new(appointment).serializable_hash }
      let(:attributes) { serialized[:data][:attributes] }

      it 'returns nil for duration_minutes when times are missing' do
        expect(attributes[:duration_minutes]).to be_nil
      end

      it 'computes is_booked as false when times are missing' do
        expect(attributes[:is_booked]).to be false
      end

      it 'computes has_capacity as false when capacity is nil' do
        expect(attributes[:has_capacity]).to be false
      end

      it 'computes has_cohort as false when cohort dates are nil' do
        expect(attributes[:has_cohort]).to be false
      end
    end

    context 'with cohort appointment structure (from get_appointments response)' do
      let(:appointment) do
        Vass::Appointment.new(
          id: 'cohort-appt-1',
          appointment_id: 'cohort-appt-1',
          veteran_id:,
          start_utc: '2026-01-15T14:00:00Z',
          end_utc: '2026-01-15T14:30:00Z',
          cohort_start_utc:,
          cohort_end_utc:,
          status: 'booked'
        )
      end

      let(:serialized) { described_class.new(appointment).serializable_hash }
      let(:attributes) { serialized[:data][:attributes] }

      it 'includes all cohort fields' do
        expect(attributes[:cohort_start_utc]).to eq(cohort_start_utc)
        expect(attributes[:cohort_end_utc]).to eq(cohort_end_utc)
      end

      it 'includes booked appointment times' do
        expect(attributes[:start_utc]).to eq('2026-01-15T14:00:00Z')
        expect(attributes[:end_utc]).to eq('2026-01-15T14:30:00Z')
      end

      it 'computes has_cohort as true' do
        expect(attributes[:has_cohort]).to be true
      end

      it 'computes is_booked as true' do
        expect(attributes[:is_booked]).to be true
      end
    end

    context 'with available slot structure (from get_availability response)' do
      let(:appointment) do
        Vass::Appointment.new(
          id: 'avail-slot-1',
          time_start_utc: '2026-01-15T14:00:00Z',
          time_end_utc: '2026-01-15T14:30:00Z',
          capacity: 5,
          status: 'available'
        )
      end

      let(:serialized) { described_class.new(appointment).serializable_hash }
      let(:attributes) { serialized[:data][:attributes] }

      it 'includes time slot fields' do
        expect(attributes[:time_start_utc]).to eq('2026-01-15T14:00:00Z')
        expect(attributes[:time_end_utc]).to eq('2026-01-15T14:30:00Z')
      end

      it 'includes capacity' do
        expect(attributes[:capacity]).to eq(5)
      end

      it 'computes effective times from time_start_utc/time_end_utc' do
        expect(attributes[:effective_start_utc]).to eq('2026-01-15T14:00:00Z')
        expect(attributes[:effective_end_utc]).to eq('2026-01-15T14:30:00Z')
      end

      it 'computes has_capacity as true' do
        expect(attributes[:has_capacity]).to be true
      end

      it 'computes is_booked as false (no start_utc/end_utc)' do
        expect(attributes[:is_booked]).to be false
      end
    end
  end
end
