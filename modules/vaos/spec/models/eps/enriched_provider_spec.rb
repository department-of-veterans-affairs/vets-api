# frozen_string_literal: true

require 'rails_helper'

describe Eps::EnrichedProvider do
  describe '.from_referral' do
    let(:provider) do
      OpenStruct.new(
        id: 'test-id',
        name: 'Test Provider'
      )
    end

    context 'when referral_detail has a phone number' do
      let(:phone_number) { '555-123-4567' }
      let(:referral_detail) { build(:ccra_referral_detail, phone_number:) }

      it 'adds the phone number to the provider' do
        result = described_class.from_referral(provider, referral_detail)
        expect(result.id).to eq(provider.id)
        expect(result.name).to eq(provider.name)
        expect(result.phone_number).to eq(phone_number)
      end
    end

    context 'when referral_detail has no phone number' do
      let(:referral_detail) do
        Ccra::ReferralDetail.new(
          'Referral' => {
            'TreatingFacilityInfo' => { 'Phone' => '' },
            'TreatingProviderInfo' => { 'Telephone' => '' }
          }
        )
      end

      it 'returns the original provider' do
        result = described_class.from_referral(provider, referral_detail)
        expect(result).to be(provider)
        expect(result.respond_to?(:phone_number)).to be false
      end
    end

    context 'when referral_detail is nil' do
      it 'returns the original provider' do
        result = described_class.from_referral(provider, nil)
        expect(result).to be(provider)
        expect(result.respond_to?(:phone_number)).to be false
      end
    end

    context 'when provider is nil' do
      it 'returns nil' do
        result = described_class.from_referral(
          nil,
          build(:ccra_referral_detail, phone_number: '555-555-5555')
        )
        expect(result).to be_nil
      end
    end
  end
end