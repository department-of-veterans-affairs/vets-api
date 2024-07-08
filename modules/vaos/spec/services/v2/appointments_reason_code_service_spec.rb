# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::AppointmentsReasonCodeService do
  describe '#extract_reason_code_fields' do
    it 'returns without modification if no reason code text exists' do
      appt = FactoryBot.build(:appointment_form_v2, :va_booked_base).attributes
      subject.send(:extract_reason_code_fields, appt)
      expect(appt[:contact]).to eq({})
    end

    it 'returns without modification if no valid reason code text fields exists' do
      appt = FactoryBot.build(:appointment_form_v2, :va_booked_invalid_reason_code_text).attributes
      subject.send(:extract_reason_code_fields, appt)
      expect(appt[:contact]).to eq({})
    end

    it 'extracts valid reason code text fields if possible' do
      appt = FactoryBot.build(:appointment_form_v2, :va_booked_valid_reason_code_text).attributes
      subject.send(:extract_reason_code_fields, appt)
      expect(appt[:contact][0]).to eq({ system: 'phone', value: '6195551234' })
      expect(appt[:contact][1]).to eq({ system: 'email', value: 'myemail72585885@unattended.com' })
    end
  end
end
