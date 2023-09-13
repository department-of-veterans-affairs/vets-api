# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::ClinicsController, type: :controller do
  describe '#unable_to_lookup_clinic?' do
    context 'when appointment is nil' do
      let(:appt) { nil }

      it 'returns true' do
        expect(subject.send(:unable_to_lookup_clinic?, appt)).to be true
      end
    end

    context 'when appointment location_id is nil' do
      let(:appt) { double(location_id: nil, clinic: :clinic) }

      it 'returns true' do
        expect(subject.send(:unable_to_lookup_clinic?, appt)).to be true
      end
    end

    context 'when appointment clinic is nil' do
      let(:appt) { double(location_id: :location_id, clinic: nil) }

      it 'returns true' do
        expect(subject.send(:unable_to_lookup_clinic?, appt)).to be true
      end
    end

    context 'when appointment and its attributes are not nil' do
      let(:appt) { double(location_id: :location_id, clinic: :clinic) }

      it 'returns false' do
        expect(subject.send(:unable_to_lookup_clinic?, appt)).to be false
      end
    end
  end

  describe '#log_unable_to_lookup_clinic' do
    let(:mock_logger) { double('Logger') }
    let(:appt) { double('OpenStruct') }

    before do
      allow(Rails).to receive(:logger).and_return(mock_logger)
    end

    context 'when appt is nil' do
      it 'logs "Appointment not found"' do
        expect(mock_logger).to receive(:info).with('VAOS last_visited_clinic', 'Appointment not found')
        subject.send(:log_unable_to_lookup_clinic, nil)
      end
    end

    context 'when location_id is nil' do
      it 'logs "Appointment does not have location_id"' do
        allow(appt).to receive(:location_id).and_return(nil)
        expect(mock_logger).to receive(:info).with('VAOS last_visited_clinic', 'Appointment does not have location id')
        subject.send(:log_unable_to_lookup_clinic, appt)
      end
    end

    context 'when clinic is nil' do
      it 'logs "Appointment does not have clinic"' do
        allow(appt).to receive(:location_id).and_return('location')
        allow(appt).to receive(:clinic).and_return(nil)
        expect(mock_logger).to receive(:info).with('VAOS last_visited_clinic', 'Appointment does not have clinic id')
        subject.send(:log_unable_to_lookup_clinic, appt)
      end
    end

    context 'when all attributes are present' do
      it 'does not log any message' do
        allow(appt).to receive(:location_id).and_return('location')
        allow(appt).to receive(:clinic).and_return('clinic')
        expect(mock_logger).not_to receive(:info)
        subject.send(:log_unable_to_lookup_clinic, appt)
      end
    end
  end

  describe '#log_no_clinic_details_found' do
    it 'logs a message when no clinic details are found' do
      station_id = '123'
      clinic_id = '456'

      allow(Rails.logger).to receive(:info)

      subject.send(:log_no_clinic_details_found, station_id, clinic_id)

      expected_log_message = 'VAOS last_visited_clinic'
      expected_details_message = "No clinic details found for station: #{station_id} and clinic: #{clinic_id}"

      expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_details_message)
    end
  end
end
