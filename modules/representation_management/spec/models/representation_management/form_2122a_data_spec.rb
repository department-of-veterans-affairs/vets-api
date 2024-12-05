# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::Form2122aData, type: :model do
  describe 'validations' do
    subject { described_class.new }

    it {
      expect(subject).to validate_inclusion_of(:veteran_service_branch)
        .in_array(described_class::VETERAN_SERVICE_BRANCHES)
    }
  end

  describe 'representative_field_truncated' do
    subject { described_class.new }

    it 'truncates characters beyond the specificied number' do
      representative = create(:accredited_individual, first_name: 'A' * 13)
      subject.representative_id = representative.id
      expect(subject.representative_field_truncated(:first_name)).to eq('A' * 12)
    end

    it 'returns the full string if it is below the truncation limit' do
      representative = create(:accredited_individual, first_name: 'A' * 5)
      subject.representative_id = representative.id
      expect(subject.representative_field_truncated(:first_name)).to eq('A' * 5)
    end

    it 'returns the full string if it is equal to the truncation limit' do
      representative = create(:accredited_individual, first_name: 'A' * 12)
      subject.representative_id = representative.id
      expect(subject.representative_field_truncated(:first_name)).to eq('A' * 12)
    end

    it 'works for every value in TRUNCATION_LIMITS' do
      representative = create(:accredited_individual)
      subject.representative_id = representative.id
      described_class::TRUNCATION_LIMITS.each do |field, limit|
        subject.representative.send("#{field}=", 'A' * (limit + 1))
        expect(subject.representative_field_truncated(field)).to eq('A' * limit)
      end
    end

    # describe '#representative_last_name_truncated' do
    #   it "returns the first 18 characters of the representative's last name" do
    #     representative = create(:accredited_individual, last_name: 'A' * 19)
    #     subject.representative_id = representative.id
    #     expect(subject.representative_last_name_truncated).to eq('A' * 18)
    #   end

    #   it 'returns the full last name if it is 17 characters or less' do
    #     representative = create(:accredited_individual, last_name: 'A' * 5)
    #     subject.representative_id = representative.id
    #     expect(subject.representative_last_name_truncated).to eq('A' * 5)
    #   end
    # end

    # describe '#representative_address_line1_truncated' do
    #   it "returns the first 30 characters of the representative's address line 1" do
    #     representative = create(:accredited_individual, address_line1: 'A' * 31)
    #     subject.representative_id = representative.id
    #     expect(subject.representative_address_line1_truncated).to eq('A' * 30)
    #   end

    #   it 'returns the full address line 1 if it is 30 characters or less' do
    #     representative = create(:accredited_individual, address_line1: 'A' * 5)
    #     subject.representative_id = representative.id
    #     expect(subject.representative_address_line1_truncated).to eq('A' * 5)
    #   end
    # end

    # describe '#representative_address_line2_truncated' do
    #   it "returns the first 5 characters of the representative's address line 2" do
    #     representative = create(:accredited_individual, address_line2: 'A' * 6)
    #     subject.representative_id = representative.id
    #     expect(subject.representative_address_line2_truncated).to eq('A' * 5)
    #   end

    #   it 'returns the full address line 2 if it is 5 characters or less' do
    #     representative = create(:accredited_individual, address_line2: 'A' * 3)
    #     subject.representative_id = representative.id
    #     expect(subject.representative_address_line2_truncated).to eq('A' * 3)
    #   end
    # end
  end
end
