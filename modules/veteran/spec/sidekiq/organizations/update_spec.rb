# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'a organization email or phone update process' do |flag_type|
  let(:id) { '123' }
  let(:address_changed) { flag_type == 'address' }
  let!(:organization) { create_organization }

  context 'when address_exists is true' do
    let(:address_exists) { true }

    before do
      allow(VAProfile::V3::AddressValidation::Service).to receive(:new).and_return(double('VAProfile::V3::AddressValidation::Service', candidate: nil)) # rubocop:disable Layout/LineLength
    end

    it 'does not call validate_address' do
      subject.perform(json_data)

      expect(VAProfile::V3::AddressValidation::Service).not_to have_received(:new)
    end
  end
end

RSpec.describe Organizations::Update do
  def create_organization
    create(:organization,
           poa: '123',
           address_line1: '123 East Main St',
           address_line2: 'Suite 1',
           address_line3: 'Address Line 3',
           address_type: 'DOMESTIC',
           city: 'My City',
           country_name: 'United States of America',
           country_code_iso3: 'USA',
           province: 'A Province',
           international_postal_code: '12345',
           state_code: 'ZZ',
           zip_code: '12345',
           zip_suffix: '6789',
           lat: '39',
           long: '-75',
           location: 'POINT(-75 39)')
  end

  describe '#perform' do
    let(:json_data) do
      [
        {
          id:,
          address: {
            address_pou: 'abc',
            address_line1: 'abc',
            address_line2: 'abc',
            address_line3: 'abc',
            city_name: 'abc',
            state: {
              state_code: 'abc'
            },
            zip_code5: 'abc',
            zip_code4: 'abc',
            country_code_iso3: 'abc'
          },
          email: 'test@example.com',
          phone_number: '999-999-9999',
          address_exists:,
          address_changed:
        }
      ].to_json
    end
    let(:api_response_v3) do
      {
        'candidate_addresses' => [
          {
            'county' => {
              'county_name' => 'Kings',
              'county_code' => '36047'
            },
            'state' => {
              'state_name' => 'New York',
              'state_code' => 'NY'
            },
            'country' => {
              'country_name' => 'United States',
              'county_code_fips' => 'US',
              'country_code_iso2' => 'US',
              'country_code_iso3' => 'USA'
            },
            'address_line1' => '37N 1st St',
            'city_name' => 'Brooklyn',
            'zip_code5' => '11249',
            'zip_code4' => '3939',
            'geocode' => {
              'calc_date' => '2020-01-23T03:15:47+00:00',
              'location_precision' => 31.0,
              'latitude' => 40.717029,
              'longitude' => -73.964956
            },
            'confidence' => 100.0,
            'address_type' => 'Domestic',
            'delivery_point_validation' => 'UNDELIVERABLE'
          }
        ]
      }
    end

    before do
      address_validation_service = VAProfile::V3::AddressValidation::Service
      allow_any_instance_of(address_validation_service).to receive(:candidate).and_return(api_response_v3)
    end

    context 'when JSON parsing fails' do
      let(:invalid_json_data) { 'invalid json' }

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with(
          "Organizations::Update: Error processing job: unexpected character: 'invalid' at line 1 column 1"
        )

        subject.perform(invalid_json_data)
      end
    end

    context 'when the organization cannot be found' do
      let(:id) { 'not_found' }
      let(:address_exists) { false }
      let(:address_changed) { true }

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with(
          a_string_matching(/Organizations::Update:.*not_found.*Organization not found/)
        )

        subject.perform(json_data)
      end
    end

    context 'when address_exists is true and address_changed is true' do
      let(:id) { '123' }
      let(:address_exists) { true }
      let(:address_changed) { true }
      let!(:organization) { create_organization }

      it 'updates the address' do
        subject.perform(json_data)
        organization.reload

        expect(organization.send('address_line1')).to eq('37N 1st St')
      end
    end

    context 'when address_exists is false and address_changed is true' do
      let(:id) { '123' }
      let(:address_exists) { false }
      let(:address_changed) { true }
      let!(:organization) { create_organization }

      it 'updates the address' do
        subject.perform(json_data)
        organization.reload

        expect(organization.send('address_line1')).to eq('37N 1st St')
      end
    end

    context 'address validation retries' do
      let(:id) { '123' }
      let(:address_exists) { true }
      let(:address_changed) { true }
      let!(:organization) { create_organization }
      let(:validation_stub) { instance_double(VAProfile::V3::AddressValidation::Service) }
      let(:api_response_with_zero_v2) do
        {
          'candidate_addresses' => [
            {
              'county' => {
                'county_name' => 'Kings',
                'county_code' => '36047'
              },
              'state' => {
                'state_name' => 'New York',
                'state_code' => 'NY'
              },
              'country' => {
                'country_name' => 'United States',
                'country_code_fips' => 'US',
                'country_code_iso2' => 'US',
                'country_code_iso3' => 'USA'
              },
              'address_line1' => '37N 1st St',
              'city_name' => 'Brooklyn',
              'zip_code5' => '11249',
              'zip_code4' => '3939',
              'geocode' => {
                'calc_date' => '2020-01-23T03:15:47+00:00',
                'location_precision' => 31.0,
                'latitude' => 0,
                'longitude' => 0
              },
              'confidence' => 100.0,
              'address_type' => 'Domestic',
              'delivery_point_validation' => 'UNDELIVERABLE'
            }
          ]
        }
      end
      let(:api_response1_v3) do
        {
          'candidate_addresses' => [
            {
              'county' => {
                'county_name' => 'Kings',
                'county_code' => '36047'
              },
              'state' => {
                'state_name' => 'New York',
                'state_code' => 'NY'
              },
              'country' => {
                'country_name' => 'United States',
                'country_code_fips' => 'US',
                'country_code_iso2' => 'US',
                'country_code_iso3' => 'USA'
              },
              'address_line1' => '37N 1st St',
              'city_name' => 'Brooklyn',
              'zip_code5' => '11249',
              'zip_code4' => '3939',
              'geocode' => {
                'calc_date' => '2020-01-23T03:15:47+00:00',
                'location_precision' => 31.0,
                'latitude' => 40.717029,
                'longitude' => -73.964956
              },
              'confidence' => 100.0,
              'address_type' => 'Domestic',
              'delivery_point_validation' => 'UNDELIVERABLE'
            }
          ]
        }
      end
      let(:api_response2_v3) do
        {
          'candidate_addresses' => [
            {
              'county' => {
                'county_name' => 'Kings',
                'county_code' => '36047'
              },
              'state' => {
                'state_name' => 'New York',
                'state_code' => 'NY'
              },
              'country' => {
                'country_name' => 'United States',
                'country_code_fips' => 'US',
                'country_code_iso2' => 'US',
                'country_code_iso3' => 'USA'
              },
              'address_line1' => '37N 2nd St',
              'city_name' => 'Brooklyn',
              'zip_code5' => '11249',
              'zip_code4' => '3939',
              'geocode' => {
                'calc_date' => '2020-01-23T03:15:47+00:00',
                'location_precision' => 31.0,
                'latitude' => 40.717029,
                'longitude' => -73.964956
              },
              'confidence' => 100.0,
              'address_type' => 'Domestic',
              'delivery_point_validation' => 'UNDELIVERABLE'
            }
          ]
        }
      end
      let(:api_response3_v3) do
        {
          'candidate_addresses' => [
            {
              'county' => {
                'county_name' => 'Kings',
                'county_code' => '36047'
              },
              'state' => {
                'state_name' => 'New York',
                'state_code' => 'NY'
              },
              'country' => {
                'country_name' => 'United States',
                'country_code_fips' => 'US',
                'country_code_iso2' => 'US',
                'country_code_iso3' => 'USA'
              },
              'address_line1' => '37N 3rd St',
              'city_name' => 'Brooklyn',
              'zip_code5' => '11249',
              'zip_code4' => '3939',
              'geocode' => {
                'calc_date' => '2020-01-23T03:15:47+00:00',
                'location_precision' => 31.0,
                'latitude' => 40.717029,
                'longitude' => -73.964956
              },
              'confidence' => 100.0,
              'address_type' => 'Domestic',
              'delivery_point_validation' => 'UNDELIVERABLE'
            }
          ]
        }
      end

      context 'when the first retry has non-zero coordinates' do
        before do
          allow(VAProfile::V3::AddressValidation::Service).to receive(:new).and_return(validation_stub)
          allow(validation_stub).to receive(:candidate).and_return(api_response_with_zero_v2, api_response1_v3)
        end

        it 'does not update the organization address' do
          expect(organization.lat).to eq(39)
          expect(organization.long).to eq(-75)
          expect(organization.address_line1).to eq('123 East Main St')

          subject.perform(json_data)
          organization.reload

          expect(organization.lat).to eq(40.717029)
          expect(organization.long).to eq(-73.964956)
          expect(organization.address_line1).to eq('37N 1st St')
        end
      end

      context 'when the second retry has non-zero coordinates' do
        before do
          allow(VAProfile::V3::AddressValidation::Service).to receive(:new).and_return(validation_stub)
          allow(validation_stub).to receive(:candidate).and_return(api_response_with_zero_v2,
                                                                   api_response_with_zero_v2,
                                                                   api_response2_v3)
        end

        it 'does not update the organization address' do
          expect(organization.lat).to eq(39)
          expect(organization.long).to eq(-75)
          expect(organization.address_line1).to eq('123 East Main St')

          subject.perform(json_data)
          organization.reload

          expect(organization.lat).to eq(40.717029)
          expect(organization.long).to eq(-73.964956)
          expect(organization.address_line1).to eq('37N 2nd St')
        end
      end

      context 'when the third retry has non-zero coordinates' do
        before do
          allow(VAProfile::V3::AddressValidation::Service).to receive(:new).and_return(validation_stub)
          allow(validation_stub).to receive(:candidate).and_return(api_response_with_zero_v2,
                                                                   api_response_with_zero_v2,
                                                                   api_response_with_zero_v2,
                                                                   api_response3_v3)
        end

        it 'updates the organization address' do
          expect(organization.lat).to eq(39)
          expect(organization.long).to eq(-75)
          expect(organization.address_line1).to eq('123 East Main St')

          subject.perform(json_data)
          organization.reload

          expect(organization.lat).to eq(40.717029)
          expect(organization.long).to eq(-73.964956)
          expect(organization.address_line1).to eq('37N 3rd St')
        end
      end

      context 'when the retry coordinates are all zero' do
        before do
          allow(VAProfile::V3::AddressValidation::Service).to receive(:new).and_return(validation_stub)
          allow(validation_stub).to receive(:candidate).and_return(api_response_with_zero_v2,
                                                                   api_response_with_zero_v2,
                                                                   api_response_with_zero_v2,
                                                                   api_response_with_zero_v2)
        end

        it 'does not update the organization address' do
          expect(organization.lat).to eq(39)
          expect(organization.long).to eq(-75)
          expect(organization.address_line1).to eq('123 East Main St')

          subject.perform(json_data)
          organization.reload

          expect(organization.lat).to eq(39)
          expect(organization.long).to eq(-75)
          expect(organization.address_line1).to eq('123 East Main St')
        end
      end
    end
  end
end
