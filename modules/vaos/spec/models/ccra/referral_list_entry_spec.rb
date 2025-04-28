# frozen_string_literal: true

require 'rails_helper'

describe Ccra::ReferralListEntry do
  describe '#initialize' do
    subject { described_class.new(valid_attributes) }

    let(:valid_attributes) do
      {
        'category_of_care' => 'CARDIOLOGY',
        'referral_number' => 'VA0000005681',
        'referral_consult_id' => '984_646372',
        'status' => 'A',
        'station_id' => '552',
        'referral_date' => '2024-03-28',
        'seoc_number_of_days' => '60',
        'referral_last_update_date_time' => '2024-03-28 16:29:52'
      }
    end

    it 'sets category_of_care correctly' do
      expect(subject.category_of_care).to eq('CARDIOLOGY')
    end

    it 'sets referral_number from referral_number' do
      expect(subject.referral_number).to eq('VA0000005681')
    end

    it 'initially sets uuid to nil' do
      expect(subject.uuid).to be_nil
    end

    it 'sets status correctly' do
      expect(subject.status).to eq('A')
    end

    it 'sets station_id correctly' do
      expect(subject.station_id).to eq('552')
    end

    it 'sets last_update_date_time correctly' do
      expect(subject.last_update_date_time).to eq('2024-03-28 16:29:52')
    end

    it 'calculates expiration_date from referral_date and seoc_number_of_days' do
      expected_date = Date.parse('2024-03-28') + 60.days
      expect(subject.expiration_date).to eq(expected_date)
    end

    context 'when referral_number is missing but referral_consult_id is present' do
      subject { described_class.new(attributes_with_only_consult_id) }

      let(:attributes_with_only_consult_id) do
        valid_attributes.except('referral_number')
      end

      it 'uses referral_consult_id as referral_number' do
        expect(subject.referral_number).to eq('984_646372')
      end
    end

    context 'with referral_expiration_date directly provided' do
      subject { described_class.new(attributes_with_expiration_date) }

      let(:attributes_with_expiration_date) do
        valid_attributes.merge('referral_expiration_date' => '2024-05-27')
      end

      it 'uses the provided expiration date' do
        expected_date = Date.parse('2024-05-27')
        expect(subject.expiration_date).to eq(expected_date)
      end
    end

    context 'with missing referral_date' do
      subject { described_class.new(attributes_without_start_date) }

      let(:attributes_without_start_date) do
        valid_attributes.except('referral_date')
      end

      it 'sets expiration_date to nil' do
        expect(subject.expiration_date).to be_nil
      end
    end

    context 'with missing seoc_number_of_days' do
      subject { described_class.new(attributes_without_days) }

      let(:attributes_without_days) do
        valid_attributes.except('seoc_number_of_days')
      end

      it 'sets expiration_date to nil' do
        expect(subject.expiration_date).to be_nil
      end
    end

    context 'with invalid referral_date' do
      subject { described_class.new(attributes_with_invalid_date) }

      let(:attributes_with_invalid_date) do
        valid_attributes.merge('referral_date' => 'invalid-date')
      end

      it 'sets expiration_date to nil' do
        expect(subject.expiration_date).to be_nil
      end
    end

    context 'with zero seoc_number_of_days' do
      subject { described_class.new(attributes_with_zero_days) }

      let(:attributes_with_zero_days) do
        valid_attributes.merge('seoc_number_of_days' => '0')
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
          'category_of_care' => 'CARDIOLOGY',
          'referral_number' => 'VA0000005681',
          'status' => 'A',
          'station_id' => '552',
          'referral_date' => '2024-03-28',
          'seoc_number_of_days' => '60'
        },
        {
          'category_of_care' => 'PODIATRY',
          'referral_number' => 'VA0000005682',
          'status' => 'AP',
          'station_id' => '552',
          'referral_date' => '2024-04-15',
          'seoc_number_of_days' => '90'
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
      expect(result[0].referral_number).to eq('VA0000005681')
      expect(result[0].status).to eq('A')
      expect(result[0].station_id).to eq('552')
      expect(result[0].uuid).to be_nil

      expect(result[1].category_of_care).to eq('PODIATRY')
      expect(result[1].referral_number).to eq('VA0000005682')
      expect(result[1].status).to eq('AP')
      expect(result[1].station_id).to eq('552')
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
