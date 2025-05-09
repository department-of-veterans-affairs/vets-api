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
      let(:referring_facility_name) { 'Bath VA Medical Center' }
      let(:referring_facility_phone) { '555-123-4567' }
      let(:referring_facility_code) { '528A6' }

      let(:referral) do
        attributes = {
          referral_number:,
          category_of_care:,
          referral_expiration_date: expiration_date,
          treating_facility:,
          treating_provider_info: {
            provider_name:,
            provider_npi:,
            telephone: provider_telephone
          },
          referring_facility_info: {
            facility_name: referring_facility_name,
            phone: referring_facility_phone,
            facility_code: referring_facility_code,
            address: {
              address1: '801 VASSAR DR NE',
              city: 'ALBUQUERQUE',
              state: 'NM',
              zip_code: '87106'
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

        # Check nested referring facility information
        referring_facility = serialized_data[:data][:attributes][:referringFacility]
        expect(referring_facility).to be_a(Hash)
        expect(referring_facility[:name]).to eq(referring_facility_name)
        expect(referring_facility[:phone]).to eq(referring_facility_phone)
        expect(referring_facility[:code]).to eq(referring_facility_code)

        # Check referring facility address
        address = referring_facility[:address]
        expect(address).to be_a(Hash)
        expect(address[:street1]).to eq('801 VASSAR DR NE')
        expect(address[:city]).to eq('ALBUQUERQUE')
        expect(address[:state]).to eq('NM')
        expect(address[:zip]).to eq('87106')
      end
    end

    context 'with a referral missing some attributes' do
      let(:referral_number) { 'VA0000005681' }
      let(:category_of_care) { 'CARDIOLOGY' }

      let(:referral) do
        attributes = {
          referral_number:,
          category_of_care:,
          referral_expiration_date: nil,
          treating_facility: nil,
          treating_provider_info: {}
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

        # Check individual top-level attributes
        %i[categoryOfCare expirationDate referralNumber uuid hasAppointments referralDate stationId].each do |attr|
          expect(serialized_data[:data][:attributes][attr]).to be_nil
        end

        # The provider is a hash with nil values, not nil itself
        expect(serialized_data[:data][:attributes][:provider].values.all?(&:nil?)).to be(true)

        # The referring facility should be nil
        expect(serialized_data[:data][:attributes][:referringFacility]).to be_nil
      end
    end
  end
end
