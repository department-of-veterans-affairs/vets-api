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
      let(:referring_facility_name) { 'Dayton VA Medical Center' }
      let(:referring_facility_phone) { '(937) 262-3800' }
      let(:referring_facility_code) { '552' }
      let(:referring_facility_address1) { '4100 West Third Street' }
      let(:referring_facility_city) { 'DAYTON' }
      let(:referring_facility_state) { 'OH' }
      let(:referring_facility_zip) { '45428' }
      let(:has_appointments) { 'Y' }

      let(:referral) do
        result = build(
          :ccra_referral_detail,
          referral_number:,
          type_of_care:,
          provider_name:,
          location:,
          expiration_date:,
          referring_facility_name:,
          referring_facility_phone:,
          referring_facility_code:,
          referring_facility_address1:,
          referring_facility_city:,
          referring_facility_state:,
          referring_facility_zip:,
          has_appointments:
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

        # Test nested provider structure
        expect(serialized_data[:data][:attributes][:provider]).to be_a(Hash)
        expect(serialized_data[:data][:attributes][:provider][:name]).to eq(provider_name)
        expect(serialized_data[:data][:attributes][:provider][:location]).to eq(location)

        # Test referring facility info
        expect(serialized_data[:data][:attributes][:referringFacilityInfo]).to be_a(Hash)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:facilityName]
        ).to eq(referring_facility_name)
        expect(serialized_data[:data][:attributes][:referringFacilityInfo][:phone]).to eq(referring_facility_phone)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:facilityCode]
        ).to eq(referring_facility_code)

        # Test referring facility address
        expect(serialized_data[:data][:attributes][:referringFacilityInfo][:address]).to be_a(Hash)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:address][:street1]
        ).to eq(referring_facility_address1)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:address][:city]
        ).to eq(referring_facility_city)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:address][:state]
        ).to eq(referring_facility_state)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:address][:zip]
        ).to eq(referring_facility_zip)

        expect(serialized_data[:data][:attributes][:expirationDate]).to eq(expiration_date)
        expect(serialized_data[:data][:attributes][:referralNumber]).to eq(referral_number)
        expect(serialized_data[:data][:attributes][:uuid]).to eq(encrypted_uuid)
        expect(serialized_data[:data][:attributes][:hasAppointments]).to be(true)
      end
    end

    context 'with different appointment indicator values' do
      let(:referral_with_y) do
        build(:ccra_referral_detail, has_appointments: 'Y')
      end

      let(:referral_with_n) do
        build(:ccra_referral_detail, has_appointments: 'N')
      end

      let(:referral_with_y_lowercase) do
        build(:ccra_referral_detail, has_appointments: 'y')
      end

      let(:referral_with_n_lowercase) do
        build(:ccra_referral_detail, has_appointments: 'n')
      end

      let(:referral_with_nil) do
        build(:ccra_referral_detail, has_appointments: nil)
      end

      it 'handles uppercase Y correctly' do
        serialized = described_class.new(referral_with_y).serializable_hash
        expect(serialized[:data][:attributes][:hasAppointments]).to be(true)
      end

      it 'handles uppercase N correctly' do
        serialized = described_class.new(referral_with_n).serializable_hash
        expect(serialized[:data][:attributes][:hasAppointments]).to be(false)
      end

      it 'handles lowercase y correctly' do
        serialized = described_class.new(referral_with_y_lowercase).serializable_hash
        expect(serialized[:data][:attributes][:hasAppointments]).to be(true)
      end

      it 'handles lowercase n correctly' do
        serialized = described_class.new(referral_with_n_lowercase).serializable_hash
        expect(serialized[:data][:attributes][:hasAppointments]).to be(false)
      end

      it 'handles nil values correctly' do
        serialized = described_class.new(referral_with_nil).serializable_hash
        expect(serialized[:data][:attributes][:hasAppointments]).to be_nil
      end
    end

    context 'with a referral missing some attributes' do
      let(:referral_number) { 'VA0000005681' }
      let(:type_of_care) { 'CARDIOLOGY' }
      let(:provider_name) { nil }
      let(:location) { nil }
      let(:expiration_date) { nil }
      let(:referring_facility_name) { 'Dayton VA Medical Center' }
      let(:referring_facility_phone) { '(937) 262-3800' }
      let(:referring_facility_code) { '552' }
      let(:referring_facility_address1) { '4100 West Third Street' }
      let(:referring_facility_city) { 'DAYTON' }
      let(:referring_facility_state) { 'OH' }
      let(:referring_facility_zip) { '45428' }
      let(:has_appointments) { 'Y' }

      let(:referral) do
        build(
          :ccra_referral_detail,
          referral_number:,
          type_of_care:,
          provider_name:,
          location:,
          expiration_date:,
          referring_facility_name:,
          referring_facility_phone:,
          referring_facility_code:,
          referring_facility_address1:,
          referring_facility_city:,
          referring_facility_state:,
          referring_facility_zip:,
          has_appointments:
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
        expect(serialized_data[:data][:attributes][:hasAppointments]).to be(true)

        # Test referring facility info
        expect(serialized_data[:data][:attributes][:referringFacilityInfo]).to be_a(Hash)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:facilityName]
        ).to eq(referring_facility_name)
        expect(serialized_data[:data][:attributes][:referringFacilityInfo][:phone]).to eq(referring_facility_phone)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:facilityCode]
        ).to eq(referring_facility_code)

        # Test referring facility address
        expect(serialized_data[:data][:attributes][:referringFacilityInfo][:address]).to be_a(Hash)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:address][:street1]
        ).to eq(referring_facility_address1)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:address][:city]
        ).to eq(referring_facility_city)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:address][:state]
        ).to eq(referring_facility_state)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:address][:zip]
        ).to eq(referring_facility_zip)
      end
    end

    context 'with a referral missing address information' do
      let(:referral_number) { 'VA0000005681' }
      let(:type_of_care) { 'CARDIOLOGY' }
      let(:referring_facility_name) { 'Dayton VA Medical Center' }
      let(:referring_facility_phone) { '(937) 262-3800' }
      let(:referring_facility_code) { '552' }
      let(:has_appointments) { 'N' }
      # No address information

      let(:referral) do
        build(
          :ccra_referral_detail,
          referral_number:,
          type_of_care:,
          referring_facility_name:,
          referring_facility_phone:,
          referring_facility_code:,
          has_appointments:,
          # Explicitly set address fields to nil
          referring_facility_address1: nil,
          referring_facility_city: nil,
          referring_facility_state: nil,
          referring_facility_zip: nil
        )
      end

      let(:serializer) { described_class.new(referral) }
      let(:serialized_data) { serializer.serializable_hash }

      it 'includes referring facility info without address' do
        expect(serialized_data[:data][:attributes][:referringFacilityInfo]).to be_a(Hash)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:facilityName]
        ).to eq(referring_facility_name)
        expect(serialized_data[:data][:attributes][:referringFacilityInfo][:phone]).to eq(referring_facility_phone)
        expect(
          serialized_data[:data][:attributes][:referringFacilityInfo][:facilityCode]
        ).to eq(referring_facility_code)
        expect(serialized_data[:data][:attributes][:referringFacilityInfo][:address]).to be_nil
        expect(serialized_data[:data][:attributes][:hasAppointments]).to be(false)
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
        expect(serialized_data[:data][:attributes][:hasAppointments]).to be_nil

        # Check provider is a hash with nil values
        provider = serialized_data[:data][:attributes][:provider]
        expect(provider).to be_a(Hash)
        expect(provider[:name]).to be_nil
        expect(provider[:location]).to be_nil
      end
    end
  end
end
