# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ccra::ReferralDetailSerializer do
  describe 'serialization' do
    context 'with a valid referral detail' do
      let(:referral_number) { 'VA0000005681' }
      let(:encrypted_uuid) { 'encrypted123456' }
      let(:category_of_care) { 'CARDIOLOGY' }
      let(:provider_name) { 'Dr. Smith' }
      let(:provider_npi) { '1234567890' }
      let(:provider_telephone) { '555-987-6543' }
      let(:treating_facility) { 'VA Medical Center' }
      let(:expiration_date) { '2024-05-27' }

      let(:referral) do
        attributes = {
          'Referral' => {
            'ReferralNumber' => referral_number,
            'CategoryOfCare' => category_of_care,
            'ReferralExpirationDate' => expiration_date,
            'TreatingFacility' => treating_facility,
            'TreatingProviderInfo' => {
              'ProviderName' => provider_name,
              'ProviderNPI' => provider_npi,
              'Telephone' => provider_telephone
            }
          }
        }
        result = Ccra::ReferralDetail.new(attributes)
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
        expect(serialized_data[:data][:attributes][:categoryOfCare]).to eq(category_of_care)
        expect(serialized_data[:data][:attributes][:expirationDate]).to eq(expiration_date)
        expect(serialized_data[:data][:attributes][:referralNumber]).to eq(referral_number)
        expect(serialized_data[:data][:attributes][:uuid]).to eq(encrypted_uuid)

        # Check nested provider information
        provider = serialized_data[:data][:attributes][:provider]
        expect(provider).to be_a(Hash)
        expect(provider[:name]).to eq(provider_name)
        expect(provider[:npi]).to eq(provider_npi)
        expect(provider[:telephone]).to eq(provider_telephone)
        expect(provider[:location]).to eq(treating_facility)
      end
    end

    context 'with a referral missing some attributes' do
      let(:referral_number) { 'VA0000005681' }
      let(:category_of_care) { 'CARDIOLOGY' }

      let(:referral) do
        attributes = {
          'Referral' => {
            'ReferralNumber' => referral_number,
            'CategoryOfCare' => category_of_care,
            'ReferralExpirationDate' => nil,
            'TreatingFacility' => nil,
            'TreatingProviderInfo' => {}
          }
        }
        Ccra::ReferralDetail.new(attributes)
      end

      let(:serializer) { described_class.new(referral) }
      let(:serialized_data) { serializer.serializable_hash }

      it 'includes nil attributes in JSON:API format' do
        expect(serialized_data[:data][:id]).to be_nil
        expect(serialized_data[:data][:type]).to eq(:referrals)
        expect(serialized_data[:data][:attributes][:categoryOfCare]).to eq(category_of_care)
        expect(serialized_data[:data][:attributes][:expirationDate]).to be_nil
        expect(serialized_data[:data][:attributes][:referralNumber]).to eq(referral_number)

        # Provider should be a hash with nil values
        provider = serialized_data[:data][:attributes][:provider]
        expect(provider).to be_a(Hash)
        expect(provider[:name]).to be_nil
        expect(provider[:location]).to be_nil
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

        # All top-level attributes should be nil
        expect(serialized_data[:data][:attributes][:categoryOfCare]).to be_nil
        expect(serialized_data[:data][:attributes][:expirationDate]).to be_nil
        expect(serialized_data[:data][:attributes][:referralNumber]).to be_nil

        # Provider should be a hash with nil values
        provider = serialized_data[:data][:attributes][:provider]
        expect(provider).to be_a(Hash)
        expect(provider[:name]).to be_nil
        expect(provider[:npi]).to be_nil
        expect(provider[:telephone]).to be_nil
        expect(provider[:location]).to be_nil

        # Referring facility should be nil since it's conditional
        expect(serialized_data[:data][:attributes][:referringFacility]).to be_nil
      end
    end
  end
end
