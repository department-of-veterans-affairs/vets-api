# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ccra::ReferralDetailSerializer do
  describe 'serialization' do
    context 'with a valid referral detail' do
      let(:referralNumber) { 'VA0000005681' }
      let(:encrypted_uuid) { 'encrypted123456' }
      let(:categoryOfCare) { 'CARDIOLOGY' }
      let(:providerName) { 'Dr. Smith' }
      let(:providerNpi) { '1234567890' }
      let(:providerTelephone) { '555-987-6543' }
      let(:treatingFacility) { 'VA Medical Center' }
      let(:expirationDate) { '2024-05-27' }
      let(:referringFacilityName) { 'Bath VA Medical Center' }
      let(:referringFacilityPhone) { '555-123-4567' }
      let(:referringFacilityCode) { '528A6' }

      let(:referral) do
        attributes = {
          'referralNumber' => referralNumber,
          'categoryOfCare' => categoryOfCare,
          'referralExpirationDate' => expirationDate,
          'treatingFacility' => treatingFacility,
          'treatingProviderInfo' => {
            'providerName' => providerName,
            'providerNpi' => providerNpi,
            'telephone' => providerTelephone
          },
          'referringFacilityInfo' => {
            'facilityName' => referringFacilityName,
            'phone' => referringFacilityPhone,
            'facilityCode' => referringFacilityCode,
            'address' => {
              'address1' => '801 VASSAR DR NE',
              'city' => 'ALBUQUERQUE',
              'state' => 'NM',
              'zipCode' => '87106'
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
        expect(serialized_data[:data][:attributes][:categoryOfCare]).to eq(categoryOfCare)
        expect(serialized_data[:data][:attributes][:expirationDate]).to eq(expirationDate)
        expect(serialized_data[:data][:attributes][:referralNumber]).to eq(referralNumber)
        expect(serialized_data[:data][:attributes][:uuid]).to eq(encrypted_uuid)

        # Check nested provider information
        provider = serialized_data[:data][:attributes][:provider]
        expect(provider).to be_a(Hash)
        expect(provider[:name]).to eq(providerName)
        expect(provider[:npi]).to eq(providerNpi)
        expect(provider[:telephone]).to eq(providerTelephone)
        expect(provider[:location]).to eq(treatingFacility)

        # Check nested referring facility information
        referring_facility = serialized_data[:data][:attributes][:referringFacility]
        expect(referring_facility).to be_a(Hash)
        expect(referring_facility[:name]).to eq(referringFacilityName)
        expect(referring_facility[:phone]).to eq(referringFacilityPhone)
        expect(referring_facility[:code]).to eq(referringFacilityCode)

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
      let(:referralNumber) { 'VA0000005681' }
      let(:categoryOfCare) { 'CARDIOLOGY' }

      let(:referral) do
        attributes = {
          'referralNumber' => referralNumber,
          'categoryOfCare' => categoryOfCare,
          'referralExpirationDate' => nil,
          'treatingFacility' => nil,
          'treatingProviderInfo' => {}
        }
        Ccra::ReferralDetail.new(attributes)
      end

      let(:serializer) { described_class.new(referral) }
      let(:serialized_data) { serializer.serializable_hash }

      it 'includes nil attributes in JSON:API format' do
        expect(serialized_data[:data][:id]).to be_nil
        expect(serialized_data[:data][:type]).to eq(:referrals)
        expect(serialized_data[:data][:attributes][:categoryOfCare]).to eq(categoryOfCare)
        expect(serialized_data[:data][:attributes][:expirationDate]).to be_nil
        expect(serialized_data[:data][:attributes][:referralNumber]).to eq(referralNumber)

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
