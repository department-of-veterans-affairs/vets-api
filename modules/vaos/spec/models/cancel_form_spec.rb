# frozen_string_literal: true

# frozen_string_literal true

require 'rails_helper'

describe VAOS::CancelForm, type: :model do
  describe 'invalid object' do
    subject { described_class.new }

    it 'validates presence of required attributes' do
      expect(subject).not_to be_valid
      expect(subject.errors.keys).to contain_exactly(:appointment_time, :clinic_id, :cancel_reason, :cancel_code)
    end

    it 'raises a Common::Exceptions::ValidationErrors when trying to fetch coerced params' do
      expect { subject.params }.to raise_error(Common::Exceptions::ValidationErrors)
    end
  end

  describe 'valid object' do
    subject do
      described_class.new(
        appointment_time: '2019-11-13T20:19:12Z',
        clinic_id: 455,
        cancel_reason: 5,
        cancel_code: 'PC',
        remarks: nil,
        clinic_name: ''
      )
    end

    it 'validates presence of required attributes' do
      expect(subject).to be_valid
    end

    it 'coerces params to correct types' do
      expect(subject.params).to eq(
        appointment_time: '11/13/19 20:19:12',
        clinic_id: '455',
        cancel_reason: '5',
        cancel_code: 'PC',
        remarks: nil, # doesn't coerce nil to ""
        clinic_name: ''
      )
    end
  end
end
