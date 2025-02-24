# frozen_string_literal: true

require 'rails_helper'

describe Ccra::ReferralDetail do
  describe '#initialize' do
    subject { described_class.new(valid_attributes) }

    let(:valid_attributes) do
      {
        'Referral' => {
          'ReferralExpirationDate' => '2024-05-27',
          'CategoryOfCare' => 'CARDIOLOGY',
          'TreatingProvider' => 'Dr. Smith',
          'TreatingFacility' => 'VA Medical Center',
          'ReferralNumber' => 'VA0000005681'
        }
      }
    end

    it 'sets all attributes correctly' do
      expect(subject.expiration_date).to eq('2024-05-27')
      expect(subject.type_of_care).to eq('CARDIOLOGY')
      expect(subject.provider_name).to eq('Dr. Smith')
      expect(subject.location).to eq('VA Medical Center')
      expect(subject.referral_number).to eq('VA0000005681')
    end

    context 'with missing Referral key' do
      subject { described_class.new(attributes_without_referral) }

      let(:attributes_without_referral) do
        {}
      end

      it 'sets all attributes to nil' do
        expect(subject.expiration_date).to be_nil
        expect(subject.type_of_care).to be_nil
        expect(subject.provider_name).to be_nil
        expect(subject.location).to be_nil
        expect(subject.referral_number).to be_nil
      end
    end

    context 'with nil Referral value' do
      subject { described_class.new(attributes_with_nil_referral) }

      let(:attributes_with_nil_referral) do
        { 'Referral' => nil }
      end

      it 'sets all attributes to nil' do
        expect(subject.expiration_date).to be_nil
        expect(subject.type_of_care).to be_nil
        expect(subject.provider_name).to be_nil
        expect(subject.location).to be_nil
        expect(subject.referral_number).to be_nil
      end
    end
  end
end
