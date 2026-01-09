# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vass::Appointment, type: :model do
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

  describe '#initialize' do
    context 'with all attributes' do
      it 'creates a valid appointment' do
        appointment = described_class.new(
          id: appointment_id,
          appointment_id:,
          veteran_id:,
          start_utc:,
          end_utc:,
          cohort_start_utc:,
          cohort_end_utc:,
          time_start_utc:,
          time_end_utc:,
          selected_agent_skills:,
          status: 'booked',
          capacity: 5,
          agent_nickname:,
          correlation_id:
        )

        expect(appointment.id).to eq(appointment_id)
        expect(appointment.appointment_id).to eq(appointment_id)
        expect(appointment.veteran_id).to eq(veteran_id)
        expect(appointment.start_utc).to eq(start_utc)
        expect(appointment.end_utc).to eq(end_utc)
        expect(appointment.cohort_start_utc).to eq(cohort_start_utc)
        expect(appointment.cohort_end_utc).to eq(cohort_end_utc)
        expect(appointment.time_start_utc).to eq(time_start_utc)
        expect(appointment.time_end_utc).to eq(time_end_utc)
        expect(appointment.selected_agent_skills).to eq(selected_agent_skills)
        expect(appointment.status).to eq('booked')
        expect(appointment.capacity).to eq(5)
        expect(appointment.agent_nickname).to eq(agent_nickname)
        expect(appointment.correlation_id).to eq(correlation_id)
      end
    end

    context 'with minimal attributes' do
      it 'creates an appointment with only required id' do
        appointment = described_class.new(id: appointment_id)

        expect(appointment.id).to eq(appointment_id)
        expect(appointment.appointment_id).to be_nil
        expect(appointment.veteran_id).to be_nil
        expect(appointment.start_utc).to be_nil
      end
    end

    context 'with invalid status' do
      it 'raises an error' do
        expect do
          described_class.new(
            id: appointment_id,
            status: 'invalid_status'
          )
        end.to raise_error(Dry::Struct::Error)
      end
    end
  end

  describe '#valid_booked_appointment?' do
    context 'when all required fields are present' do
      it 'returns true' do
        appointment = described_class.new(
          id: appointment_id,
          appointment_id:,
          veteran_id:,
          start_utc:,
          end_utc:
        )

        expect(appointment.valid_booked_appointment?).to be true
      end
    end

    context 'when appointment_id is missing' do
      it 'returns false' do
        appointment = described_class.new(
          id: appointment_id,
          veteran_id:,
          start_utc:,
          end_utc:
        )

        expect(appointment.valid_booked_appointment?).to be false
      end
    end

    context 'when veteran_id is missing' do
      it 'returns false' do
        appointment = described_class.new(
          id: appointment_id,
          appointment_id:,
          start_utc:,
          end_utc:
        )

        expect(appointment.valid_booked_appointment?).to be false
      end
    end

    context 'when start_utc is missing' do
      it 'returns false' do
        appointment = described_class.new(
          id: appointment_id,
          appointment_id:,
          veteran_id:,
          end_utc:
        )

        expect(appointment.valid_booked_appointment?).to be false
      end
    end

    context 'when end_utc is missing' do
      it 'returns false' do
        appointment = described_class.new(
          id: appointment_id,
          appointment_id:,
          veteran_id:,
          start_utc:
        )

        expect(appointment.valid_booked_appointment?).to be false
      end
    end
  end

  describe '#valid_time_slot?' do
    context 'when start_utc and end_utc are present' do
      it 'returns true' do
        appointment = described_class.new(
          id: appointment_id,
          start_utc:,
          end_utc:
        )

        expect(appointment.valid_time_slot?).to be true
      end
    end

    context 'when time_start_utc and time_end_utc are present' do
      it 'returns true' do
        appointment = described_class.new(
          id: appointment_id,
          time_start_utc:,
          time_end_utc:
        )

        expect(appointment.valid_time_slot?).to be true
      end
    end

    context 'when no time fields are present' do
      it 'returns false' do
        appointment = described_class.new(id: appointment_id)

        expect(appointment.valid_time_slot?).to be false
      end
    end
  end

  describe '#cohort?' do
    context 'when cohort dates are present' do
      it 'returns true' do
        appointment = described_class.new(
          id: appointment_id,
          cohort_start_utc:,
          cohort_end_utc:
        )

        expect(appointment.cohort?).to be true
      end
    end

    context 'when cohort_start_utc is missing' do
      it 'returns false' do
        appointment = described_class.new(
          id: appointment_id,
          cohort_end_utc:
        )

        expect(appointment.cohort?).to be false
      end
    end

    context 'when cohort_end_utc is missing' do
      it 'returns false' do
        appointment = described_class.new(
          id: appointment_id,
          cohort_start_utc:
        )

        expect(appointment.cohort?).to be false
      end
    end
  end

  describe '#selected_skills?' do
    context 'when skills are present' do
      it 'returns true' do
        appointment = described_class.new(
          id: appointment_id,
          selected_agent_skills:
        )

        expect(appointment.selected_skills?).to be true
      end
    end

    context 'when skills array is empty' do
      it 'returns false' do
        appointment = described_class.new(
          id: appointment_id,
          selected_agent_skills: []
        )

        expect(appointment.selected_skills?).to be false
      end
    end

    context 'when skills are nil' do
      it 'returns false' do
        appointment = described_class.new(id: appointment_id)

        expect(appointment.selected_skills?).to be false
      end
    end
  end

  describe '#booked?' do
    context 'when start_utc and end_utc are present' do
      it 'returns true' do
        appointment = described_class.new(
          id: appointment_id,
          start_utc:,
          end_utc:
        )

        expect(appointment.booked?).to be true
      end
    end

    context 'when times are missing' do
      it 'returns false' do
        appointment = described_class.new(id: appointment_id)

        expect(appointment.booked?).to be false
      end
    end
  end

  describe '#available_capacity?' do
    context 'when capacity is positive' do
      it 'returns true' do
        appointment = described_class.new(
          id: appointment_id,
          capacity: 5
        )

        expect(appointment.available_capacity?).to be true
      end
    end

    context 'when capacity is zero' do
      it 'returns false' do
        appointment = described_class.new(
          id: appointment_id,
          capacity: 0
        )

        expect(appointment.available_capacity?).to be false
      end
    end

    context 'when capacity is nil' do
      it 'returns false' do
        appointment = described_class.new(id: appointment_id)

        expect(appointment.available_capacity?).to be false
      end
    end
  end

  describe '#effective_start_utc' do
    context 'when start_utc is present' do
      it 'returns start_utc' do
        appointment = described_class.new(
          id: appointment_id,
          start_utc:,
          time_start_utc:
        )

        expect(appointment.effective_start_utc).to eq(start_utc)
      end
    end

    context 'when only time_start_utc is present' do
      it 'returns time_start_utc' do
        appointment = described_class.new(
          id: appointment_id,
          time_start_utc:
        )

        expect(appointment.effective_start_utc).to eq(time_start_utc)
      end
    end

    context 'when neither is present' do
      it 'returns nil' do
        appointment = described_class.new(id: appointment_id)

        expect(appointment.effective_start_utc).to be_nil
      end
    end
  end

  describe '#effective_end_utc' do
    context 'when end_utc is present' do
      it 'returns end_utc' do
        appointment = described_class.new(
          id: appointment_id,
          end_utc:,
          time_end_utc:
        )

        expect(appointment.effective_end_utc).to eq(end_utc)
      end
    end

    context 'when only time_end_utc is present' do
      it 'returns time_end_utc' do
        appointment = described_class.new(
          id: appointment_id,
          time_end_utc:
        )

        expect(appointment.effective_end_utc).to eq(time_end_utc)
      end
    end

    context 'when neither is present' do
      it 'returns nil' do
        appointment = described_class.new(id: appointment_id)

        expect(appointment.effective_end_utc).to be_nil
      end
    end
  end

  describe '#start_time' do
    context 'with valid ISO8601 timestamp in start_utc' do
      it 'returns a Time object' do
        appointment = described_class.new(
          id: appointment_id,
          start_utc:
        )

        expect(appointment.start_time).to be_a(Time)
        expect(appointment.start_time.to_s).to include('2026-01-15 14:00:00')
      end
    end

    context 'with valid ISO8601 timestamp in time_start_utc' do
      it 'returns a Time object' do
        appointment = described_class.new(
          id: appointment_id,
          time_start_utc:
        )

        expect(appointment.start_time).to be_a(Time)
        expect(appointment.start_time.to_s).to include('2026-01-16 10:00:00')
      end
    end

    context 'with nil times' do
      it 'returns nil' do
        appointment = described_class.new(id: appointment_id)

        expect(appointment.start_time).to be_nil
      end
    end

    context 'with invalid timestamp' do
      it 'returns nil' do
        appointment = described_class.new(
          id: appointment_id,
          start_utc: 'invalid'
        )

        expect(appointment.start_time).to be_nil
      end
    end
  end

  describe '#end_time' do
    context 'with valid ISO8601 timestamp in end_utc' do
      it 'returns a Time object' do
        appointment = described_class.new(
          id: appointment_id,
          end_utc:
        )

        expect(appointment.end_time).to be_a(Time)
        expect(appointment.end_time.to_s).to include('2026-01-15 14:30:00')
      end
    end

    context 'with valid ISO8601 timestamp in time_end_utc' do
      it 'returns a Time object' do
        appointment = described_class.new(
          id: appointment_id,
          time_end_utc:
        )

        expect(appointment.end_time).to be_a(Time)
        expect(appointment.end_time.to_s).to include('2026-01-16 10:30:00')
      end
    end

    context 'with nil times' do
      it 'returns nil' do
        appointment = described_class.new(id: appointment_id)

        expect(appointment.end_time).to be_nil
      end
    end

    context 'with invalid timestamp' do
      it 'returns nil' do
        appointment = described_class.new(
          id: appointment_id,
          end_utc: 'invalid'
        )

        expect(appointment.end_time).to be_nil
      end
    end
  end

  describe '#cohort_start_time' do
    context 'with valid ISO8601 timestamp' do
      it 'returns a Time object' do
        appointment = described_class.new(
          id: appointment_id,
          cohort_start_utc:
        )

        expect(appointment.cohort_start_time).to be_a(Time)
        expect(appointment.cohort_start_time.to_s).to include('2026-01-01')
      end
    end

    context 'with nil cohort_start_utc' do
      it 'returns nil' do
        appointment = described_class.new(id: appointment_id)

        expect(appointment.cohort_start_time).to be_nil
      end
    end
  end

  describe '#cohort_end_time' do
    context 'with valid ISO8601 timestamp' do
      it 'returns a Time object' do
        appointment = described_class.new(
          id: appointment_id,
          cohort_end_utc:
        )

        expect(appointment.cohort_end_time).to be_a(Time)
        expect(appointment.cohort_end_time.to_s).to include('2026-01-31')
      end
    end

    context 'with nil cohort_end_utc' do
      it 'returns nil' do
        appointment = described_class.new(id: appointment_id)

        expect(appointment.cohort_end_time).to be_nil
      end
    end
  end

  describe '#duration_minutes' do
    context 'with valid start and end times in start_utc/end_utc' do
      it 'calculates duration in minutes' do
        appointment = described_class.new(
          id: appointment_id,
          start_utc:,
          end_utc:
        )

        expect(appointment.duration_minutes).to eq(30)
      end
    end

    context 'with valid start and end times in time_start_utc/time_end_utc' do
      it 'calculates duration in minutes' do
        appointment = described_class.new(
          id: appointment_id,
          time_start_utc:,
          time_end_utc:
        )

        expect(appointment.duration_minutes).to eq(30)
      end
    end

    context 'with missing start time' do
      it 'returns nil' do
        appointment = described_class.new(
          id: appointment_id,
          end_utc:
        )

        expect(appointment.duration_minutes).to be_nil
      end
    end

    context 'with missing end time' do
      it 'returns nil' do
        appointment = described_class.new(
          id: appointment_id,
          start_utc:
        )

        expect(appointment.duration_minutes).to be_nil
      end
    end

    context 'with different durations' do
      it 'calculates 60 minutes correctly' do
        appointment = described_class.new(
          id: appointment_id,
          start_utc: '2026-01-15T14:00:00Z',
          end_utc: '2026-01-15T15:00:00Z'
        )

        expect(appointment.duration_minutes).to eq(60)
      end

      it 'calculates 15 minutes correctly' do
        appointment = described_class.new(
          id: appointment_id,
          start_utc: '2026-01-15T14:00:00Z',
          end_utc: '2026-01-15T14:15:00Z'
        )

        expect(appointment.duration_minutes).to eq(15)
      end
    end
  end

  describe 'status enum' do
    it 'accepts "booked" status' do
      appointment = described_class.new(id: appointment_id, status: 'booked')
      expect(appointment.status).to eq('booked')
    end

    it 'accepts "available" status' do
      appointment = described_class.new(id: appointment_id, status: 'available')
      expect(appointment.status).to eq('available')
    end

    it 'accepts "cancelled" status' do
      appointment = described_class.new(id: appointment_id, status: 'cancelled')
      expect(appointment.status).to eq('cancelled')
    end

    it 'accepts "pending" status' do
      appointment = described_class.new(id: appointment_id, status: 'pending')
      expect(appointment.status).to eq('pending')
    end
  end
end
