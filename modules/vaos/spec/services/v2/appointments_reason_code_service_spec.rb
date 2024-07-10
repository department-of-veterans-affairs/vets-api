# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::AppointmentsReasonCodeService do
  describe '#extract_reason_code_fields' do
    it 'returns without modification if no reason code text exists' do
      appt = FactoryBot.build(:appointment_form_v2, :va_proposed_base).attributes
      subject.extract_reason_code_fields(appt)
      expect(appt[:contact]).to eq({})
    end

    it 'returns without modification if no valid reason code text fields exists' do
      appt = FactoryBot.build(:appointment_form_v2, :va_proposed_invalid_reason_code_text).attributes
      subject.extract_reason_code_fields(appt)
      expect(appt[:contact]).to eq({})
    end

    it 'returns without modification for cc request' do
      appt = FactoryBot.build(:appointment_form_v2, :community_cares_valid_reason_code_text).attributes
      subject.extract_reason_code_fields(appt)
      expect(appt[:contact]).to eq({})
    end

    it 'returns without modification for va booked' do
      appt = FactoryBot.build(:appointment_form_v2, :va_booked_valid_reason_code_text).attributes
      subject.extract_reason_code_fields(appt)
      expect(appt[:contact]).to eq({})
    end

    it 'extract valid reason text for va request' do
      appt = FactoryBot.build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      subject.extract_reason_code_fields(appt)
      expect(appt[:contact][:telecom][0]).to eq({ system: 'phone', value: '6195551234' })
      expect(appt[:contact][:telecom][1]).to eq({ system: 'email', value: 'myemail72585885@unattended.com' })
    end
  end
end
