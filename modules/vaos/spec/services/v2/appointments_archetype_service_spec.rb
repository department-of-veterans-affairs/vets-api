# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::AppointmentsArchetypeService do
  include ActiveSupport::Testing::TimeHelpers

  let(:appt_med) do
    { kind: 'clinic', service_category: [{ coding:
                 [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'REGULAR' }] }] }
  end
  let(:appt_non) do
    { kind: 'clinic', service_category: [{ coding:
                 [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'SERVICE CONNECTED' }] }],
      service_type: 'SERVICE CONNECTED', service_types: [{ coding: [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'SERVICE CONNECTED' }] }] }
  end
  let(:appt_cnp) do
    { kind: 'clinic', service_category: [{ coding:
                 [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'COMPENSATION & PENSION' }] }] }
  end
  let(:appt_cc) do
    { kind: 'cc', service_category: [{ coding:
                 [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'REGULAR' }] }] }
  end
  let(:appt_telehealth) do
    { kind: 'telehealth', service_category: [{ coding:
                 [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'REGULAR' }] }] }
  end
  let(:appt_no_service_cat) { { kind: 'clinic' } }

  describe '#booked?' do
    it 'returns true when the appointment status is booked' do
      appt = {
        status: 'booked'
      }

      expect(subject.send(:booked?, appt)).to eq(true)
    end

    it 'returns false when the appointment status is not booked' do
      appt = {
        status: 'cancelled'
      }

      expect(subject.send(:booked?, appt)).to eq(false)
    end

    it 'returns false when the appointment does not contain status' do
      appt = {}

      expect(subject.send(:booked?, appt)).to eq(false)
    end

    it 'raises an ArgumentError when the appointment nil' do
      expect { subject.send(:booked?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end
  end

  describe '#avs_applicable?' do
    before { travel_to(DateTime.parse('2023-09-26T10:00:00-07:00')) }
    after { travel_back }

    let(:past_appointment) { { status: 'booked', start: '2023-09-25T10:00:00-07:00' } }
    let(:future_appointment) { { status: 'booked', start: '2023-09-27T11:00:00-07:00' } }
    let(:unbooked_appointment) { { status: 'pending', start: '2023-09-25T10:00:00-07:00' } }

    it 'returns true if the appointment is booked and is in the past' do
      expect(subject.send(:avs_applicable?, past_appointment)).to be true
    end

    it 'returns false if the appointment is not booked' do
      expect(subject.send(:avs_applicable?, unbooked_appointment)).to be false
    end

    it 'returns false on a booked future appointment' do
      expect(subject.send(:avs_applicable?, future_appointment)).to be false
    end
  end

  describe '#medical?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:medical?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true for medical appointments' do
      expect(subject.send(:medical?, appt_med)).to eq(true)
    end

    it 'returns false for non-medical appointments' do
      expect(subject.send(:medical?, appt_non)).to eq(false)
    end
  end

  describe '#no_service_cat?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:no_service_cat?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true for appointments without a service category' do
      expect(subject.send(:no_service_cat?, appt_no_service_cat)).to eq(true)
    end

    it 'returns false for appointments with a service category' do
      expect(subject.send(:no_service_cat?, appt_non)).to eq(false)
    end
  end

  describe '#cnp?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:cnp?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true for compensation and pension appointments' do
      expect(subject.send(:cnp?, appt_cnp)).to eq(true)
    end

    it 'returns false for non compensation and pension appointments' do
      expect(subject.send(:cnp?, appt_non)).to eq(false)
    end
  end

  describe '#cc?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:cc?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true for community care appointments' do
      expect(subject.send(:cc?, appt_cc)).to eq(true)
    end

    it 'returns false for non community care appointments' do
      expect(subject.send(:cc?, appt_non)).to eq(false)
    end
  end

  describe '#telehealth?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.send(:telehealth?, nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true for telehealth appointments' do
      expect(subject.send(:telehealth?, appt_telehealth)).to eq(true)
    end

    it 'returns false for telehealth appointments' do
      expect(subject.send(:telehealth?, appt_non)).to eq(false)
    end
  end

  describe '#codes' do
    context 'when nil is passed in' do
      it 'returns an empty array' do
        expect(subject.send(:codes, nil)).to eq([])
      end
    end

    context 'when no codable concept code is present' do
      it 'returns an empty array' do
        x = [{ coding: [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', display: 'REGULAR' }],
               text: 'REGULAR' }]
        expect(subject.send(:codes, x)).to eq([])
      end
    end

    context 'when a codable concept code is present' do
      it 'returns an array of codable concept codes' do
        x = [{ coding: [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'REGULAR' }],
               text: 'REGULAR' }]
        expect(subject.send(:codes, x)).to eq(['REGULAR'])
      end
    end

    context 'when multiple codable concept codes are present' do
      it 'returns an array of codable concept codes' do
        x = [{ coding: [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'REGULAR' },
                        { system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'TELEHEALTH' }],
               text: 'REGULAR' }]
        expect(subject.send(:codes, x)).to eq(%w[REGULAR TELEHEALTH])
      end
    end

    context 'when multiple codable concepts with single codes are present' do
      it 'returns an array of codable concept codes' do
        x = [{ coding: [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'REGULAR' }],
               text: 'REGULAR' },
             { coding: [{ system: 'http://www.va.gov/terminology/vistadefinedterms/409_1', code: 'TELEHEALTH' }],
               text: 'TELEHEALTH' }]
        expect(subject.send(:codes, x)).to eq(%w[REGULAR TELEHEALTH])
      end
    end
  end
end
