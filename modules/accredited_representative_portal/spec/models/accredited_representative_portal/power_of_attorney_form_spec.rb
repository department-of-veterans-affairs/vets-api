# frozen_string_literal: true

require_relative '../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyForm, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:power_of_attorney_request) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:data_ciphertext) }
  end

  describe 'creation' do
    it 'creates a valid form' do
      form = build(:power_of_attorney_form, data_ciphertext: 'test_data')
      expect(form).to be_valid
    end
  end
end
