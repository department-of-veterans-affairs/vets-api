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

    it 'raises StandardError if the field does not have a truncation limit defined' do
      representative = create(:accredited_individual)
      subject.representative_id = representative.id
      expect { subject.representative_field_truncated(:address_line3) }.to raise_error(StandardError)
    end
  end

  describe 'representative_zip_code_expanded' do
    subject { described_class.new }

    it 'returns the zip code and suffix if the suffix is present' do
      representative = create(:accredited_individual, zip_code: '12345', zip_suffix: '6789')
      subject.representative_id = representative.id
      expect(subject.representative_zip_code_expanded).to eq(%w[12345 6789])
    end

    it 'returns the expanded zip code if the suffix is not present' do
      representative = create(:accredited_individual, zip_code: '123456789')
      subject.representative_id = representative.id
      expect(subject.representative_zip_code_expanded).to eq(%w[12345 6789])
    end
  end
end
