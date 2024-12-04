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

  describe 'truncate methods' do
    subject { described_class.new }

    describe '#representative_first_name_truncated' do
      it "returns the first 12 characters of the representative's first name" do
        representative = create(:accredited_individual, first_name: 'A' * 13)
        subject.representative_id = representative.id
        expect(subject.representative_first_name_truncated).to eq('A' * 12)
      end

      it 'returns the full first name if it is 12 characters or less' do
        representative = create(:accredited_individual, first_name: 'A' * 5)
        subject.representative_id = representative.id
        expect(subject.representative_first_name_truncated).to eq('A' * 5)
      end
    end

    describe '#representative_last_name_truncated' do
      it "returns the first 18 characters of the representative's last name" do
        representative = create(:accredited_individual, last_name: 'A' * 19)
        subject.representative_id = representative.id
        expect(subject.representative_last_name_truncated).to eq('A' * 18)
      end

      it 'returns the full last name if it is 17 characters or less' do
        representative = create(:accredited_individual, last_name: 'A' * 5)
        subject.representative_id = representative.id
        expect(subject.representative_last_name_truncated).to eq('A' * 5)
      end
    end
  end
end
