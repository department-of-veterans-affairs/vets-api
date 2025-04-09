# frozen_string_literal: true

require 'rails_helper'

describe Ccra::ReferralListEntry do
  describe '#initialize' do
    subject { described_class.new(valid_attributes) }

    let(:valid_attributes) do
      {
        'CategoryOfCare' => 'CARDIOLOGY',
        'ID' => '5682',
        'StartDate' => '2024-03-28',
        'SEOCNumberOfDays' => '60'
      }
    end

    it 'sets type_of_care from CategoryOfCare' do
      expect(subject.type_of_care).to eq('CARDIOLOGY')
    end

    it 'sets referral_id from ID' do
      expect(subject.referral_id).to eq('5682')
    end

    it 'initially sets uuid to nil' do
      expect(subject.uuid).to be_nil
    end

    it 'calculates expiration_date from StartDate and SEOCNumberOfDays' do
      expected_date = Date.parse('2024-03-28') + 60.days
      expect(subject.expiration_date).to eq(expected_date)
    end

    context 'with missing StartDate' do
      subject { described_class.new(attributes_without_start_date) }

      let(:attributes_without_start_date) do
        valid_attributes.except('StartDate')
      end

      it 'sets expiration_date to nil' do
        expect(subject.expiration_date).to be_nil
      end
    end

    context 'with missing SEOCNumberOfDays' do
      subject { described_class.new(attributes_without_days) }

      let(:attributes_without_days) do
        valid_attributes.except('SEOCNumberOfDays')
      end

      it 'sets expiration_date to nil' do
        expect(subject.expiration_date).to be_nil
      end
    end

    context 'with invalid StartDate' do
      subject { described_class.new(attributes_with_invalid_date) }

      let(:attributes_with_invalid_date) do
        valid_attributes.merge('StartDate' => 'invalid-date')
      end

      it 'sets expiration_date to nil' do
        expect(subject.expiration_date).to be_nil
      end
    end

    context 'with zero SEOCNumberOfDays' do
      subject { described_class.new(attributes_with_zero_days) }

      let(:attributes_with_zero_days) do
        valid_attributes.merge('SEOCNumberOfDays' => '0')
      end

      it 'sets expiration_date to nil' do
        expect(subject.expiration_date).to be_nil
      end
    end
  end

  describe '.build_collection' do
    let(:referral_data) do
      [
        {
          'CategoryOfCare' => 'CARDIOLOGY',
          'ID' => '5682',
          'StartDate' => '2024-03-28',
          'SEOCNumberOfDays' => '60'
        },
        {
          'CategoryOfCare' => 'PODIATRY',
          'ID' => '5683',
          'StartDate' => '2024-04-15',
          'SEOCNumberOfDays' => '90'
        }
      ]
    end

    it 'creates an array of ReferralListEntry objects' do
      result = described_class.build_collection(referral_data)
      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(described_class))
    end

    it 'sets correct attributes for each entry' do
      result = described_class.build_collection(referral_data)
      expect(result[0].type_of_care).to eq('CARDIOLOGY')
      expect(result[0].referral_id).to eq('5682')
      expect(result[0].uuid).to be_nil
      expect(result[1].type_of_care).to eq('PODIATRY')
      expect(result[1].referral_id).to eq('5683')
      expect(result[1].uuid).to be_nil
    end

    context 'with nil input' do
      it 'returns an empty array' do
        result = described_class.build_collection(nil)
        expect(result).to eq([])
      end
    end

    context 'with empty array input' do
      it 'returns an empty array' do
        result = described_class.build_collection([])
        expect(result).to eq([])
      end
    end
  end
end
