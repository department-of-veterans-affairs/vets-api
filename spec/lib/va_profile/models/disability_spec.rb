# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/disability'

RSpec.describe VAProfile::Models::Disability, type: :model do
  describe 'validations' do
    subject { VAProfile::Models::Disability.new(combined_service_connected_rating_percentage: '30') }

    it 'validates a valid value' do
      expect(subject).to be_valid
      expect(subject.combined_service_connected_rating_percentage).to be('30')
    end

    it 'validates presence of combined_service_connected_rating_percentage' do
      subject.combined_service_connected_rating_percentage = nil
      expect(subject).not_to be_valid
      expect(subject.errors.details[:combined_service_connected_rating_percentage]).to include(error: :blank)
    end

    it 'validates combined_service_connected_rating_percentage not more than 3 characters' do
      subject.combined_service_connected_rating_percentage = '1000'
      expect(subject).not_to be_valid
      expect(subject.errors.details[:combined_service_connected_rating_percentage]).to include(error: :too_long,
                                                                                               count: 3)
    end
  end

  describe '.in_json' do
    it 'returns the correct JSON structure' do
      expected_json = {
        bios: [
          {
            bioPath: 'disabilityRating'
          }
        ]
      }.to_json

      expect(described_class.in_json).to eq(expected_json)
    end
  end

  describe '.build_disability_rating' do
    context 'when rating is present' do
      let(:rating) { '90' }

      it 'returns a Disability instance with the correct rating' do
        disability_rating = described_class.build_disability_rating(rating)

        expect(disability_rating).to be_a(VAProfile::Models::Disability)
        expect(disability_rating.combined_service_connected_rating_percentage).to eq(rating)
      end
    end

    context 'when rating is nil' do
      it 'returns nil' do
        expect(described_class.build_disability_rating(nil)).to be_nil
      end
    end
  end
end
