# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::Form2122aData, type: :model do
  describe 'validations' do
    subject { described_class.new }

    it {
      expect(subject).to validate_inclusion_of(:veteran_service_branch)
        .in_array(described_class::VETERAN_SERVICE_BRANCHES)
    }

    it {
      expect(subject).to validate_inclusion_of(:representative_type)
        .in_array(described_class::REPRESENTATIVE_TYPES)
    }

    it { expect(subject).to validate_presence_of(:representative_type) }
    it { expect(subject).to validate_presence_of(:representative_first_name) }
    it { expect(subject).to validate_length_of(:representative_first_name).is_at_most(12) }
    it { expect(subject).to validate_length_of(:representative_middle_initial).is_at_most(1) }
    it { expect(subject).to validate_presence_of(:representative_last_name) }
    it { expect(subject).to validate_length_of(:representative_last_name).is_at_most(18) }
    it { expect(subject).to validate_presence_of(:representative_address_line1) }
    it { expect(subject).to validate_length_of(:representative_address_line1).is_at_most(30) }
    it { expect(subject).to validate_length_of(:representative_address_line2).is_at_most(5) }
    it { expect(subject).to validate_presence_of(:representative_city) }
    it { expect(subject).to validate_length_of(:representative_city).is_at_most(18) }
    it { expect(subject).to validate_presence_of(:representative_country) }
    it { expect(subject).to validate_length_of(:representative_country).is_equal_to(2) }
    it { expect(subject).to validate_presence_of(:representative_state_code) }
    it { expect(subject).to validate_length_of(:representative_state_code).is_equal_to(2) }
    it { expect(subject).to validate_presence_of(:representative_zip_code) }
    it { expect(subject).to validate_length_of(:representative_zip_code).is_equal_to(5) }
    it { expect(subject).to allow_value('12345').for(:representative_zip_code) }
    it { expect(subject).not_to allow_value('1234A').for(:representative_zip_code) }
    it { expect(subject).not_to allow_value('12345').for(:representative_zip_code_suffix) }
    it { expect(subject).to allow_value('1234').for(:representative_zip_code_suffix) }
    it { expect(subject).to validate_length_of(:representative_zip_code_suffix).is_equal_to(4) }
    it { expect(subject).to validate_presence_of(:representative_phone) }
    it { expect(subject).to validate_length_of(:representative_phone).is_equal_to(10) }
    it { expect(subject).to allow_value('1234567890').for(:representative_phone) }
    it { expect(subject).not_to allow_value('123456789A').for(:representative_phone) }
    it { expect(subject).not_to allow_value('123456789').for(:representative_phone) }
  end
end
