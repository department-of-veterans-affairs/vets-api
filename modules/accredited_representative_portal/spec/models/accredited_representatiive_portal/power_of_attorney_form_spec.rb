# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyForm, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:power_of_attorney_request) }
  end

  describe 'validations' do
    it 'validates uniqueness of power_of_attorney_request_id' do
      form = create(:power_of_attorney_form)
      duplicate_form = build(:power_of_attorney_form, power_of_attorney_request: form.power_of_attorney_request)

      expect(duplicate_form).not_to be_valid
      expect(duplicate_form.errors[:power_of_attorney_request_id]).to include('has already been taken')
    end

    it { is_expected.to validate_presence_of(:data_ciphertext) }
    it { is_expected.to validate_length_of(:city_bidx).is_equal_to(44) }
    it { is_expected.to validate_length_of(:state_bidx).is_equal_to(44) }
    it { is_expected.to validate_length_of(:zipcode_bidx).is_equal_to(44) }
  end

  describe 'creation' do
    it 'creates a valid form' do
      form = build(:power_of_attorney_form, data_ciphertext: 'test_data')
      expect(form).to be_valid
    end
  end
end
