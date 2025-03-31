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
          'ReferralNumber' => 'VA0000005681',
          'ProviderPhone' => '555-123-4567'
        }
      }
    end

    it 'sets all attributes correctly' do
      expect(subject.expiration_date).to eq('2024-05-27')
      expect(subject.type_of_care).to eq('CARDIOLOGY')
      expect(subject.provider_name).to eq('Dr. Smith')
      expect(subject.location).to eq('VA Medical Center')
      expect(subject.referral_number).to eq('VA0000005681')
      expect(subject.phone_number).to eq('555-123-4567')
    end

    context 'with facility phone instead of provider phone' do
      let(:attributes_with_facility_phone) do
        {
          'Referral' => {
            'ReferralExpirationDate' => '2024-05-27',
            'CategoryOfCare' => 'CARDIOLOGY',
            'TreatingProvider' => 'Dr. Smith',
            'TreatingFacility' => 'VA Medical Center',
            'ReferralNumber' => 'VA0000005681',
            'FacilityPhone' => '555-987-6543'
          }
        }
      end

      it 'uses facility phone when provider phone is not available' do
        detail = described_class.new(attributes_with_facility_phone)
        expect(detail.phone_number).to eq('555-987-6543')
      end
    end

    context 'with both provider and facility phone' do
      let(:attributes_with_both_phones) do
        {
          'Referral' => {
            'ReferralExpirationDate' => '2024-05-27',
            'CategoryOfCare' => 'CARDIOLOGY',
            'TreatingProvider' => 'Dr. Smith',
            'TreatingFacility' => 'VA Medical Center',
            'ReferralNumber' => 'VA0000005681',
            'ProviderPhone' => '555-123-4567',
            'FacilityPhone' => '555-987-6543'
          }
        }
      end

      it 'prefers provider phone over facility phone' do
        detail = described_class.new(attributes_with_both_phones)
        expect(detail.phone_number).to eq('555-123-4567')
      end
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
        expect(subject.phone_number).to be_nil
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
        expect(subject.phone_number).to be_nil
      end
    end
  end
end
