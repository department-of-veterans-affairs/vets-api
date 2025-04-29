# frozen_string_literal: true

require 'rails_helper'

describe Ccra::ReferralListEntry do
  describe '#initialize' do
    subject { described_class.new(valid_attributes) }

    let(:valid_attributes) do
      {
        category_of_care: 'CARDIOLOGY',
        referral_number: '5682',
        referral_expiration_date: '2024-05-27',
        station_id: '528A6',
        status: 'AP',
        referral_last_update_date_time: '2024-03-28T14:30:00Z'
      }
    end

    it 'sets category_of_care from categoryOfCare' do
      expect(subject.category_of_care).to eq('CARDIOLOGY')
    end

    it 'sets referral_number from referralNumber' do
      expect(subject.referral_number).to eq('5682')
    end

    it 'initially sets uuid to nil' do
      expect(subject.uuid).to be_nil
    end

    it 'sets expiration_date directly from referralExpirationDate' do
      expect(subject.expiration_date).to eq(Date.parse('2024-05-27'))
    end

    context 'with invalid referralExpirationDate' do
      subject { described_class.new(attributes_with_invalid_date) }

      let(:attributes_with_invalid_date) do
        valid_attributes.merge(referral_expiration_date: 'invalid-date')
      end

      it 'sets expiration_date to nil' do
        expect(subject.expiration_date).to be_nil
      end
    end

    context 'with missing referralExpirationDate' do
      subject { described_class.new(attributes_without_expiration) }

      let(:attributes_without_expiration) do
        valid_attributes.except(:referral_expiration_date)
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
          category_of_care: 'CARDIOLOGY',
          referral_number: '5682',
          referral_expiration_date: '2024-05-27',
          station_id: '528A6',
          status: 'AP',
          referral_last_update_date_time: '2024-03-28T14:30:00Z'
        },
        {
          category_of_care: 'PODIATRY',
          referral_number: '5683',
          referral_expiration_date: '2024-08-15',
          station_id: '552',
          status: 'AP',
          referral_last_update_date_time: '2024-04-15T09:45:00Z'
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
      expect(result[0].category_of_care).to eq('CARDIOLOGY')
      expect(result[0].referral_number).to eq('5682')
      expect(result[0].uuid).to be_nil
      expect(result[0].expiration_date).to eq(Date.parse('2024-05-27'))
      expect(result[1].category_of_care).to eq('PODIATRY')
      expect(result[1].referral_number).to eq('5683')
      expect(result[1].uuid).to be_nil
      expect(result[1].expiration_date).to eq(Date.parse('2024-08-15'))
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
