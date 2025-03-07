# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ccra::ReferralDetailSerializer do
  describe '#as_json' do
    context 'with a valid referral detail' do
      let(:referral_number) { 'VA0000005681' }
      let(:type_of_care) { 'CARDIOLOGY' }
      let(:provider_name) { 'Dr. Smith' }
      let(:location) { 'VA Medical Center' }
      let(:expiration_date) { '2024-05-27' }

      let(:referral) do
        build(
          :ccra_referral_detail,
          referral_number:,
          type_of_care:,
          provider_name:,
          location:,
          expiration_date:
        )
      end

      let(:serializer) { described_class.new(referral) }
      let(:serialized_data) { serializer.as_json }

      it 'serializes the referral detail correctly' do
        expect(serialized_data[:id]).to eq(referral_number)
        expect(serialized_data[:type_of_care]).to eq(type_of_care)
        expect(serialized_data[:provider_name]).to eq(provider_name)
        expect(serialized_data[:location]).to eq(location)
        expect(serialized_data[:expiration_date]).to eq(expiration_date)
      end
    end

    context 'with a referral missing some attributes' do
      let(:referral_number) { 'VA0000005681' }
      let(:type_of_care) { 'CARDIOLOGY' }
      let(:provider_name) { nil }
      let(:location) { nil }
      let(:expiration_date) { nil }

      let(:referral) do
        build(
          :ccra_referral_detail,
          referral_number:,
          type_of_care:,
          provider_name:,
          location:,
          expiration_date:
        )
      end

      let(:serializer) { described_class.new(referral) }
      let(:serialized_data) { serializer.as_json }

      it 'omits nil attributes' do
        expect(serialized_data[:id]).to eq(referral_number)
        expect(serialized_data[:type_of_care]).to eq(type_of_care)
        expect(serialized_data).not_to have_key(:provider_name)
        expect(serialized_data).not_to have_key(:location)
        expect(serialized_data).not_to have_key(:expiration_date)
      end
    end

    context 'with a nil referral' do
      # Create an empty ReferralDetail object that would result from a nil response
      let(:referral) do
        Ccra::ReferralDetail.new({})
      end

      let(:serializer) { described_class.new(referral) }
      let(:serialized_data) { serializer.as_json }

      it 'returns an empty hash' do
        expect(serialized_data).to be_a(Hash)
        expect(serialized_data).to be_empty
      end
    end
  end
end
