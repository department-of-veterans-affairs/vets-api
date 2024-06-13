# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::AppointmentsController, type: :request do
  let(:va_booked_request_body) do
    FactoryBot.build(:appointment_form_v2, :va_booked).attributes
  end

  describe '#add_timezone_offset' do
    let(:desired_date) { '2022-09-21T00:00:00+00:00'.to_datetime }

    context 'with a date and timezone' do
      it 'adds the timezone offset to the date' do
        date_with_offset = subject.send(:add_timezone_offset, desired_date, 'America/New_York')
        expect(date_with_offset.to_s).to eq('2022-09-21T00:00:00-04:00')
      end
    end

    context 'with a date and nil timezone' do
      it 'leaves the date as is' do
        date_with_offset = subject.send(:add_timezone_offset, desired_date, nil)
        expect(date_with_offset.to_s).to eq(desired_date.to_s)
      end
    end

    context 'with a nil date' do
      it 'throws a ParameterMissing exception' do
        expect do
          subject.send(:add_timezone_offset, nil, 'America/New_York')
        end.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end
  end

  describe '#modify_desired_date' do
    context 'with a request body and facility timezone' do
      it 'updates the direct scheduled appt desired date with facilities time zone offset' do
        subject.send(:modify_desired_date, va_booked_request_body, 'America/Denver')
        expect(va_booked_request_body[:extension][:desired_date].to_s).to eq('2022-11-30T00:00:00-07:00')
      end
    end
  end

  describe '#get_clinic_memoized' do
    context 'when clinic service throws an error' do
      it 'returns nil' do
        allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic_with_cache)
          .and_raise(Common::Exceptions::BackendServiceException.new('VAOS_502', {}))

        expect(subject.send(:get_clinic_memoized, '123', '3456')).to be_nil
      end
    end
  end

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
end
