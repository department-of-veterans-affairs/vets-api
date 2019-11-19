# frozen_string_literal: true

require 'rails_helper'

describe VAOS::VAAppointmentRequest, type: :model do
  describe 'valid object' do
    subject { described_class.new(build(:va_appointment_request).attributes) }

    it 'validates presence of required attributes' do
      expect(subject).to be_valid
    end

    it 'coerces params to correct types' do
      expect(subject.params).to eq(
        appointment_time: '11/13/2019 20:19:12',
        clinic_id: '455',
        cancel_reason: '5',
        cancel_code: 'PC',
        remarks: nil, # doesn't coerce nil to ""
        clinic_name: ''
      )
    end
  end
end
