# frozen_string_literal: true

require 'rails_helper'

describe Ccra::ReferralListEntry do
  describe '#initialize' do
    subject { described_class.new(valid_attributes) }

    let(:valid_attributes) do
      {
        'categoryOfCare' => 'CARDIOLOGY',
        'referralNumber' => 'VA0000005681',
        'referralConsultId' => '984_646372',
        'status' => 'A',
        'stationId' => '552',
        'referralDate' => '2024-03-28',
        'seocNumberOfDays' => '60',
        'referralLastUpdateDateTime' => '2024-03-28 16:29:52'
      }
    end

    it 'sets categoryOfCare correctly' do
      expect(subject.categoryOfCare).to eq('CARDIOLOGY')
    end

    it 'sets referralNumber from referralNumber' do
      expect(subject.referralNumber).to eq('VA0000005681')
    end

    it 'initially sets uuid to nil' do
      expect(subject.uuid).to be_nil
    end

    it 'sets status correctly' do
      expect(subject.status).to eq('A')
    end

    it 'sets stationId correctly' do
      expect(subject.stationId).to eq('552')
    end

    it 'sets lastUpdateDateTime correctly' do
      expect(subject.lastUpdateDateTime).to eq('2024-03-28 16:29:52')
    end

    it 'calculates expirationDate from referralDate and seocNumberOfDays' do
      expected_date = Date.parse('2024-03-28') + 60.days
      expect(subject.expirationDate).to eq(expected_date)
    end

    context 'when referralNumber is missing but referralConsultId is present' do
      subject { described_class.new(attributes_with_only_consult_id) }

      let(:attributes_with_only_consult_id) do
        valid_attributes.except('referralNumber')
      end

      it 'uses referralConsultId as referralNumber' do
        expect(subject.referralNumber).to eq('984_646372')
      end
    end

    context 'with referralExpirationDate directly provided' do
      subject { described_class.new(attributes_with_expiration_date) }

      let(:attributes_with_expiration_date) do
        valid_attributes.merge('referralExpirationDate' => '2024-05-27')
      end

      it 'uses the provided expiration date' do
        expected_date = Date.parse('2024-05-27')
        expect(subject.expirationDate).to eq(expected_date)
      end
    end

    context 'with missing referralDate' do
      subject { described_class.new(attributes_without_start_date) }

      let(:attributes_without_start_date) do
        valid_attributes.except('referralDate')
      end

      it 'sets expirationDate to nil' do
        expect(subject.expirationDate).to be_nil
      end
    end

    context 'with missing seocNumberOfDays' do
      subject { described_class.new(attributes_without_days) }

      let(:attributes_without_days) do
        valid_attributes.except('seocNumberOfDays')
      end

      it 'sets expirationDate to nil' do
        expect(subject.expirationDate).to be_nil
      end
    end

    context 'with invalid referralDate' do
      subject { described_class.new(attributes_with_invalid_date) }

      let(:attributes_with_invalid_date) do
        valid_attributes.merge('referralDate' => 'invalid-date')
      end

      it 'sets expirationDate to nil' do
        expect(subject.expirationDate).to be_nil
      end
    end

    context 'with zero seocNumberOfDays' do
      subject { described_class.new(attributes_with_zero_days) }

      let(:attributes_with_zero_days) do
        valid_attributes.merge('seocNumberOfDays' => '0')
      end

      it 'sets expirationDate to nil' do
        expect(subject.expirationDate).to be_nil
      end
    end
  end

  describe '.build_collection' do
    let(:referral_data) do
      [
        {
          'categoryOfCare' => 'CARDIOLOGY',
          'referralNumber' => 'VA0000005681',
          'status' => 'A',
          'stationId' => '552',
          'referralDate' => '2024-03-28',
          'seocNumberOfDays' => '60'
        },
        {
          'categoryOfCare' => 'PODIATRY',
          'referralNumber' => 'VA0000005682',
          'status' => 'AP',
          'stationId' => '552',
          'referralDate' => '2024-04-15',
          'seocNumberOfDays' => '90'
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
      expect(result[0].categoryOfCare).to eq('CARDIOLOGY')
      expect(result[0].referralNumber).to eq('VA0000005681')
      expect(result[0].status).to eq('A')
      expect(result[0].stationId).to eq('552')
      expect(result[0].uuid).to be_nil

      expect(result[1].categoryOfCare).to eq('PODIATRY')
      expect(result[1].referralNumber).to eq('VA0000005682')
      expect(result[1].status).to eq('AP')
      expect(result[1].stationId).to eq('552')
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
