# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vass::AppointmentAdapter, type: :model do
  describe '.from_api' do
    context 'with complete booked appointment data' do
      subject { described_class.from_api(api_data) }

      let(:api_data) do
        {
          'appointmentId' => 'appt-abc123',
          'veteranId' => 'vet-uuid-123',
          'startUTC' => '2026-01-07T10:00:00Z',
          'endUTC' => '2026-01-07T10:30:00Z',
          'cohortStartUtc' => '2026-01-05T00:00:00Z',
          'cohortEndUtc' => '2026-01-20T23:59:59Z',
          'agentNickname' => 'Dr. Smith',
          'appointmentStatus' => 'Scheduled',
          'correlationId' => 'corr-123'
        }
      end

      it 'returns a Vass::Appointment' do
        expect(subject).to be_a(Vass::Appointment)
      end

      it 'transforms appointmentId to id and appointment_id' do
        expect(subject.id).to eq('appt-abc123')
        expect(subject.appointment_id).to eq('appt-abc123')
      end

      it 'transforms veteranId to veteran_id' do
        expect(subject.veteran_id).to eq('vet-uuid-123')
      end

      it 'transforms startUTC to start_utc (capital to lowercase)' do
        expect(subject.start_utc).to eq('2026-01-07T10:00:00Z')
      end

      it 'transforms endUTC to end_utc (capital to lowercase)' do
        expect(subject.end_utc).to eq('2026-01-07T10:30:00Z')
      end

      it 'transforms cohortStartUtc to cohort_start_utc (camel to snake)' do
        expect(subject.cohort_start_utc).to eq('2026-01-05T00:00:00Z')
      end

      it 'transforms cohortEndUtc to cohort_end_utc (camel to snake)' do
        expect(subject.cohort_end_utc).to eq('2026-01-20T23:59:59Z')
      end

      it 'transforms agentNickname to agent_nickname' do
        expect(subject.agent_nickname).to eq('Dr. Smith')
      end

      it 'transforms correlationId to correlation_id' do
        expect(subject.correlation_id).to eq('corr-123')
      end

      it 'maps appointmentStatus "Scheduled" to status "booked"' do
        expect(subject.status).to eq('booked')
      end

      it 'calculates duration correctly' do
        expect(subject.duration_minutes).to eq(30)
      end
    end

    context 'with available time slot data' do
      subject { described_class.from_api(api_data) }

      let(:api_data) do
        {
          'appointmentId' => 'slot-789',
          'timeStartUTC' => '2026-01-08T11:00:00Z',
          'timeEndUTC' => '2026-01-08T11:30:00Z',
          'capacity' => 5,
          'appointmentStatus' => 'Available'
        }
      end

      it 'transforms timeStartUTC to time_start_utc' do
        expect(subject.time_start_utc).to eq('2026-01-08T11:00:00Z')
      end

      it 'transforms timeEndUTC to time_end_utc' do
        expect(subject.time_end_utc).to eq('2026-01-08T11:30:00Z')
      end

      it 'includes capacity' do
        expect(subject.capacity).to eq(5)
      end

      it 'maps appointmentStatus "Available" to status "available"' do
        expect(subject.status).to eq('available')
      end

      it 'calculates effective times from time_start_utc/time_end_utc' do
        expect(subject.effective_start_utc).to eq('2026-01-08T11:00:00Z')
        expect(subject.effective_end_utc).to eq('2026-01-08T11:30:00Z')
      end
    end

    context 'with minimal data' do
      subject { described_class.from_api(api_data) }

      let(:api_data) do
        {
          'appointmentId' => 'minimal-123'
        }
      end

      it 'creates appointment with only provided fields' do
        expect(subject.id).to eq('minimal-123')
        expect(subject.appointment_id).to eq('minimal-123')
        expect(subject.start_utc).to be_nil
        expect(subject.veteran_id).to be_nil
      end
    end

    context 'with missing appointmentId' do
      subject { described_class.from_api(api_data) }

      let(:api_data) do
        {
          'startUTC' => '2026-01-07T10:00:00Z',
          'endUTC' => '2026-01-07T10:30:00Z'
        }
      end

      it 'generates a UUID for id' do
        expect(subject.id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
      end

      it 'leaves appointment_id nil' do
        expect(subject.appointment_id).to be_nil
      end
    end

    context 'with nil data' do
      it 'returns nil' do
        expect(described_class.from_api(nil)).to be_nil
      end
    end

    context 'with empty hash' do
      it 'returns nil' do
        expect(described_class.from_api({})).to be_nil
      end
    end

    context 'with selectedAgentSkills array' do
      subject { described_class.from_api(api_data) }

      let(:api_data) do
        {
          'appointmentId' => 'appt-123',
          'selectedAgentSkills' => %w[skill-1 skill-2 skill-3]
        }
      end

      it 'transforms selectedAgentSkills to selected_agent_skills' do
        expect(subject.selected_agent_skills).to eq(%w[skill-1 skill-2 skill-3])
      end
    end
  end

  describe '.from_api_collection' do
    context 'with multiple appointments' do
      subject { described_class.from_api_collection(api_appointments) }

      let(:api_appointments) do
        [
          {
            'appointmentId' => 'appt-1',
            'startUTC' => '2026-01-07T10:00:00Z',
            'endUTC' => '2026-01-07T10:30:00Z',
            'appointmentStatus' => 'Scheduled'
          },
          {
            'appointmentId' => 'appt-2',
            'startUTC' => '2026-01-08T14:00:00Z',
            'endUTC' => '2026-01-08T14:30:00Z',
            'appointmentStatus' => 'Scheduled'
          },
          {
            'appointmentId' => 'slot-3',
            'timeStartUTC' => '2026-01-09T11:00:00Z',
            'timeEndUTC' => '2026-01-09T11:30:00Z',
            'capacity' => 3,
            'appointmentStatus' => 'Available'
          }
        ]
      end

      it 'returns an array' do
        expect(subject).to be_an(Array)
      end

      it 'transforms all appointments' do
        expect(subject.length).to eq(3)
      end

      it 'transforms each appointment correctly' do
        expect(subject[0].appointment_id).to eq('appt-1')
        expect(subject[1].appointment_id).to eq('appt-2')
        expect(subject[2].appointment_id).to eq('slot-3')
      end

      it 'all elements are Vass::Appointment instances' do
        expect(subject.all? { |a| a.is_a?(Vass::Appointment) }).to be true
      end
    end

    context 'with mixed valid and invalid data' do
      subject { described_class.from_api_collection(api_appointments) }

      let(:api_appointments) do
        [
          { 'appointmentId' => 'appt-1', 'startUTC' => '2026-01-07T10:00:00Z' },
          nil,
          { 'appointmentId' => 'appt-2', 'startUTC' => '2026-01-08T10:00:00Z' },
          {},
          { 'appointmentId' => 'appt-3', 'startUTC' => '2026-01-09T10:00:00Z' }
        ]
      end

      it 'filters out nil and empty entries' do
        expect(subject.length).to eq(3)
        expect(subject.map(&:appointment_id)).to eq(%w[appt-1 appt-2 appt-3])
      end
    end

    context 'with nil collection' do
      it 'returns empty array' do
        expect(described_class.from_api_collection(nil)).to eq([])
      end
    end

    context 'with empty array' do
      it 'returns empty array' do
        expect(described_class.from_api_collection([])).to eq([])
      end
    end
  end

  describe '.map_status' do
    it 'maps "Scheduled" to "booked"' do
      expect(described_class.map_status('Scheduled')).to eq('booked')
    end

    it 'maps "Available" to "available"' do
      expect(described_class.map_status('Available')).to eq('available')
    end

    it 'maps "Cancelled" to "cancelled"' do
      expect(described_class.map_status('Cancelled')).to eq('cancelled')
    end

    it 'lowercases unmapped statuses' do
      expect(described_class.map_status('Pending')).to eq('pending')
      expect(described_class.map_status('CONFIRMED')).to eq('confirmed')
    end

    it 'returns nil for nil input' do
      expect(described_class.map_status(nil)).to be_nil
    end

    it 'returns nil for empty string' do
      expect(described_class.map_status('')).to be_nil
    end
  end

  describe 'integration with real VASS API response structure' do
    context 'with booked cohort appointment (from VCR cassette)' do
      subject { described_class.from_api(api_data) }

      let(:api_data) do
        {
          'appointmentId' => 'appt-abc123',
          'startUTC' => '2026-01-07T10:00:00Z',
          'endUTC' => '2026-01-07T10:30:00Z',
          'agentId' => 'agent-456',
          'agentNickname' => 'Dr. Smith',
          'appointmentStatusCode' => 1,
          'appointmentStatus' => 'Scheduled',
          'cohortStartUtc' => '2026-01-05T00:00:00Z',
          'cohortEndUtc' => '2026-01-20T23:59:59Z'
        }
      end

      it 'transforms to valid appointment model' do
        expect(subject).to be_a(Vass::Appointment)
        expect(subject.valid_booked_appointment?).to be false # missing veteran_id
        expect(subject.booked?).to be true
        expect(subject.cohort?).to be true
      end
    end

    context 'with availability slot (from VCR cassette)' do
      subject { described_class.from_api(api_data) }

      let(:api_data) do
        {
          'timeStartUTC' => '2026-01-07T10:00:00Z',
          'timeEndUTC' => '2026-01-07T10:30:00Z',
          'capacity' => 5
        }
      end

      it 'transforms to valid time slot' do
        expect(subject).to be_a(Vass::Appointment)
        expect(subject.valid_time_slot?).to be true
        expect(subject.available_capacity?).to be true
        expect(subject.booked?).to be false
      end
    end
  end
end
