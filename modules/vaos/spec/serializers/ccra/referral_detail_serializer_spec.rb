# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ccra::ReferralDetailSerializer do
  describe 'serialization' do
    context 'with a valid referral detail' do
      let(:referral_number) { 'VA0000005681' }
      let(:encrypted_uuid) { 'encrypted123456' }
      let(:type_of_care) { 'CARDIOLOGY' }
      let(:provider_name) { 'Dr. Smith' }
      let(:location) { 'VA Medical Center' }
      let(:expiration_date) { '2024-05-27' }

      let(:referral) do
        result = build(
          :ccra_referral_detail,
          referral_number:,
          type_of_care:,
          provider_name:,
          location:,
          expiration_date:
        )
        result.uuid = encrypted_uuid
        result
      end

      let(:serializer) { described_class.new(referral) }
      let(:serialized_data) { serializer.serializable_hash }

      it 'returns a hash with data' do
        expect(serialized_data).to have_key(:data)
      end

      it 'serializes the referral detail correctly' do
        expect(serialized_data[:data][:id]).to eq(encrypted_uuid)
        expect(serialized_data[:data][:type]).to eq(:referrals)
        expect(serialized_data[:data][:attributes][:categoryOfCare]).to eq(type_of_care)
        expect(serialized_data[:data][:attributes][:provider]).to be_a(Hash)
        expect(serialized_data[:data][:attributes][:provider][:name]).to eq(provider_name)
        expect(serialized_data[:data][:attributes][:provider][:location]).to eq(location)
        expect(serialized_data[:data][:attributes][:expirationDate]).to eq(expiration_date)
        expect(serialized_data[:data][:attributes][:referralNumber]).to eq(referral_number)
        expect(serialized_data[:data][:attributes][:uuid]).to eq(encrypted_uuid)
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
      let(:serialized_data) { serializer.serializable_hash }

      it 'includes nil attributes in JSON:API format' do
        expect(serialized_data[:data][:id]).to be_nil
        expect(serialized_data[:data][:type]).to eq(:referrals)
        expect(serialized_data[:data][:attributes][:categoryOfCare]).to eq(type_of_care)
        expect(serialized_data[:data][:attributes][:provider]).to be_a(Hash)
        expect(serialized_data[:data][:attributes][:provider][:name]).to be_nil
        expect(serialized_data[:data][:attributes][:provider][:location]).to be_nil
        expect(serialized_data[:data][:attributes][:expirationDate]).to be_nil
        expect(serialized_data[:data][:attributes][:referralNumber]).to eq(referral_number)
      end
    end

    context 'with a nil referral' do
      # Create an empty ReferralDetail object that would result from a nil response
      let(:referral) do
        Ccra::ReferralDetail.new({})
      end

      let(:serializer) { described_class.new(referral) }
      let(:serialized_data) { serializer.serializable_hash }

      it 'returns a hash with data containing null attributes' do
        expect(serialized_data).to have_key(:data)
        expect(serialized_data[:data][:attributes]).to be_a(Hash)

        # Check non-nested attributes are nil
        expect(serialized_data[:data][:attributes][:categoryOfCare]).to be_nil
        expect(serialized_data[:data][:attributes][:expirationDate]).to be_nil
        expect(serialized_data[:data][:attributes][:referralNumber]).to be_nil
        expect(serialized_data[:data][:attributes][:uuid]).to be_nil

        # Check provider is a hash with nil values
        provider = serialized_data[:data][:attributes][:provider]
        expect(provider).to be_a(Hash)
        expect(provider[:name]).to be_nil
        expect(provider[:location]).to be_nil
      end
    end
  end
end
