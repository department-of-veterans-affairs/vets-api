# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditedIndividualsUpdate do
  def address_attributes
    {
      address_line1: '123 East Main St',
      address_line2: 'Suite 1',
      address_line3: 'Address Line 3',
      city: 'My City',
      state_code: 'ZZ',
      zip_code: '12345',
      zip_suffix: '6789',
      country_code_iso3: 'USA',
      country_name: 'United States of America',
      province: 'A Province',
      international_postal_code: '12345',
      address_type: 'DOMESTIC'
    }
  end

  def create_accredited_individual
    create(:accredited_individual,
           { id:,
             first_name: 'Bob',
             last_name: 'Law',
             lat: '39',
             long: '-75',
             email: 'email@example.com',
             location: 'POINT(-75 39)',
             phone: '111-111-1111' }.merge(address_attributes))
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
            city: 'abc',
            state: {
              state_code: 'abc'
            },
            zip_code5: 'abc',
            zip_code4: 'abc',
            country_code_iso3: 'abc'
          },
          email: 'test@example.com',
          phone: '999-999-9999'
        }
      ].to_json
    end
    let(:api_response_v2) do
      {
        'candidate_addresses' => [
          {
            'address' => {
              'county' => {
                'name' => 'Kings',
                'county_fips_code' => '36047'
              },
              'state_province' => {
                'name' => 'New York',
                'code' => 'NY'
              },
              'country' => {
                'name' => 'United States',
                'code' => 'USA',
                'fips_code' => 'US',
                'iso2_code' => 'US',
                'iso3_code' => 'USA'
              },
              'address_line1' => '37N 1st St',
              'city' => 'Brooklyn',
              'zip_code5' => '11249',
              'zip_code4' => '3939'
            },
            'geocode' => {
              'calc_date' => '2020-01-23T03:15:47+00:00',
              'location_precision' => 31.0,
              'latitude' => 40.717029,
              'longitude' => -73.964956
            },
            'address_meta_data' => {
              'confidence_score' => 100.0,
              'address_type' => 'Domestic',
              'delivery_point_validation' => 'UNDELIVERABLE',
              'validation_key' => -646_932_106
            }
          }
        ]
      }
    end

    before do
      allow_any_instance_of(VAProfile::AddressValidation::Service).to receive(:candidate).and_return(api_response_v2)
    end

    context 'when JSON parsing fails' do
      let(:invalid_json_data) { 'invalid json' }

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with(
          'RepresentationManagement::AccreditedIndividualsUpdate: Error processing job: ' \
          "unexpected character: 'invalid json' at line 1 column 1"
        )

        subject.perform(invalid_json_data)
      end
    end

    context 'when the representative cannot be found' do
      let(:id) { 'not_found' }

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with(
          'RepresentationManagement::AccreditedIndividualsUpdate: Update failed for Rep id: not_found: ' \
          "Couldn't find AccreditedIndividual with 'id'=not_found"
        )

        subject.perform(json_data)
      end
    end

    context 'when changing address' do
      let(:id) { SecureRandom.uuid }
      let!(:representative) { create_accredited_individual }

      it 'updates the address' do
        subject.perform(json_data)
        representative.reload

        expect(representative.send('address_line1')).to eq('37N 1st St')
      end
    end

    context 'address validation retries' do
      let(:id) { SecureRandom.uuid }
      let!(:representative) { create_accredited_individual }
      let(:validation_stub) { instance_double(VAProfile::AddressValidation::Service) }
      let(:api_response_with_zero_v2) do
        {
          'candidate_addresses' => [
            {
              'address' => {
                'county' => {
                  'name' => 'Kings',
                  'county_fips_code' => '36047'
                },
                'state_province' => {
                  'name' => 'New York',
                  'code' => 'NY'
                },
                'country' => {
                  'name' => 'United States',
                  'code' => 'USA',
                  'fips_code' => 'US',
                  'iso2_code' => 'US',
                  'iso3_code' => 'USA'
                },
                'address_line1' => '37N 1st St',
                'city' => 'Brooklyn',
                'zip_code5' => '11249',
                'zip_code4' => '3939'
              },
              'geocode' => {
                'calc_date' => '2020-01-23T03:15:47+00:00',
                'location_precision' => 31.0,
                'latitude' => 0,
                'longitude' => 0
              },
              'address_meta_data' => {
                'confidence_score' => 100.0,
                'address_type' => 'Domestic',
                'delivery_point_validation' => 'UNDELIVERABLE',
                'validation_key' => -646_932_106
              }
            }
          ]
        }
      end
      let(:api_response1_v2) do
        {
          'candidate_addresses' => [
            {
              'address' => {
                'county' => {
                  'name' => 'Kings',
                  'county_fips_code' => '36047'
                },
                'state_province' => {
                  'name' => 'New York',
                  'code' => 'NY'
                },
                'country' => {
                  'name' => 'United States',
                  'code' => 'USA',
                  'fips_code' => 'US',
                  'iso2_code' => 'US',
                  'iso3_code' => 'USA'
                },
                'address_line1' => '37N 1st St',
                'city' => 'Brooklyn',
                'zip_code5' => '11249',
                'zip_code4' => '3939'
              },
              'geocode' => {
                'calc_date' => '2020-01-23T03:15:47+00:00',
                'location_precision' => 31.0,
                'latitude' => 40.717029,
                'longitude' => -73.964956
              },
              'address_meta_data' => {
                'confidence_score' => 100.0,
                'address_type' => 'Domestic',
                'delivery_point_validation' => 'UNDELIVERABLE',
                'validation_key' => -646_932_106
              }
            }
          ]
        }
      end
      let(:api_response2_v2) do
        {
          'candidate_addresses' => [
            {
              'address' => {
                'county' => {
                  'name' => 'Kings',
                  'county_fips_code' => '36047'
                },
                'state_province' => {
                  'name' => 'New York',
                  'code' => 'NY'
                },
                'country' => {
                  'name' => 'United States',
                  'code' => 'USA',
                  'fips_code' => 'US',
                  'iso2_code' => 'US',
                  'iso3_code' => 'USA'
                },
                'address_line1' => '37N 2nd St',
                'city' => 'Brooklyn',
                'zip_code5' => '11249',
                'zip_code4' => '3939'
              },
              'geocode' => {
                'calc_date' => '2020-01-23T03:15:47+00:00',
                'location_precision' => 31.0,
                'latitude' => 40.717029,
                'longitude' => -73.964956
              },
              'address_meta_data' => {
                'confidence_score' => 100.0,
                'address_type' => 'Domestic',
                'delivery_point_validation' => 'UNDELIVERABLE',
                'validation_key' => -646_932_106
              }
            }
          ]
        }
      end
      let(:api_response3_v2) do
        {
          'candidate_addresses' => [
            {
              'address' => {
                'county' => {
                  'name' => 'Kings',
                  'county_fips_code' => '36047'
                },
                'state_province' => {
                  'name' => 'New York',
                  'code' => 'NY'
                },
                'country' => {
                  'name' => 'United States',
                  'code' => 'USA',
                  'fips_code' => 'US',
                  'iso2_code' => 'US',
                  'iso3_code' => 'USA'
                },
                'address_line1' => '37N 3rd St',
                'city' => 'Brooklyn',
                'zip_code5' => '11249',
                'zip_code4' => '3939'
              },
              'geocode' => {
                'calc_date' => '2020-01-23T03:15:47+00:00',
                'location_precision' => 31.0,
                'latitude' => 40.717029,
                'longitude' => -73.964956
              },
              'address_meta_data' => {
                'confidence_score' => 100.0,
                'address_type' => 'Domestic',
                'delivery_point_validation' => 'UNDELIVERABLE',
                'validation_key' => -646_932_106
              }
            }
          ]
        }
      end

      context 'when the first retry has non-zero coordinates' do
        before do
          allow(VAProfile::AddressValidation::Service).to receive(:new).and_return(validation_stub)
          allow(validation_stub).to receive(:candidate).and_return(api_response_with_zero_v2, api_response1_v2)
        end

        it 'does not update the representative address' do
          expect(representative.lat).to eq(39)
          expect(representative.long).to eq(-75)
          expect(representative.address_line1).to eq('123 East Main St')

          subject.perform(json_data)
          representative.reload

          expect(representative.lat).to eq(40.717029)
          expect(representative.long).to eq(-73.964956)
          expect(representative.address_line1).to eq('37N 1st St')
        end
      end

      context 'when the second retry has non-zero coordinates' do
        before do
          allow(VAProfile::AddressValidation::Service).to receive(:new).and_return(validation_stub)
          allow(validation_stub).to receive(:candidate).and_return(api_response_with_zero_v2, api_response_with_zero_v2,
                                                                   api_response2_v2)
        end

        it 'does not update the representative address' do
          expect(representative.lat).to eq(39)
          expect(representative.long).to eq(-75)
          expect(representative.address_line1).to eq('123 East Main St')

          subject.perform(json_data)
          representative.reload

          expect(representative.lat).to eq(40.717029)
          expect(representative.long).to eq(-73.964956)
          expect(representative.address_line1).to eq('37N 2nd St')
        end
      end

      context 'when the third retry has non-zero coordinates' do
        before do
          allow(VAProfile::AddressValidation::Service).to receive(:new).and_return(validation_stub)
          allow(validation_stub).to receive(:candidate).and_return(api_response_with_zero_v2, api_response_with_zero_v2,
                                                                   api_response_with_zero_v2, api_response3_v2)
        end

        it 'updates the representative address' do
          expect(representative.lat).to eq(39)
          expect(representative.long).to eq(-75)
          expect(representative.address_line1).to eq('123 East Main St')

          subject.perform(json_data)
          representative.reload

          expect(representative.lat).to eq(40.717029)
          expect(representative.long).to eq(-73.964956)
          expect(representative.address_line1).to eq('37N 3rd St')
        end
      end

      context 'when the retry coordinates are all zero' do
        before do
          allow(VAProfile::AddressValidation::Service).to receive(:new).and_return(validation_stub)
          allow(validation_stub).to receive(:candidate).and_return(api_response_with_zero_v2, api_response_with_zero_v2,
                                                                   api_response_with_zero_v2, api_response_with_zero_v2)
        end

        it 'does not update the representative address' do
          expect(representative.lat).to eq(39)
          expect(representative.long).to eq(-75)
          expect(representative.address_line1).to eq('123 East Main St')

          subject.perform(json_data)
          representative.reload

          expect(representative.lat).to eq(39)
          expect(representative.long).to eq(-75)
          expect(representative.address_line1).to eq('123 East Main St')
        end
      end
    end
  end

  describe 'V3/AddressValidation' do
    def create_accredited_individual
      create(:accredited_individual,
             { id:,
               first_name: 'Bob',
               last_name: 'Law',
               lat: '39',
               long: '-75',
               email: 'email@example.com',
               location: 'POINT(-75 39)',
               phone: '111-111-1111' }.merge(address_attributes))
    end
    describe '#perform V3/AddressValidation' do
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
            phone: '999-999-9999'
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
        validation_service = VAProfile::V3::AddressValidation::Service
        allow(Flipper).to receive(:enabled?).with(:remove_pciu).and_return(true)
        allow_any_instance_of(validation_service).to receive(:candidate).and_return(api_response_v3)
      end

      context 'when JSON parsing fails' do
        let(:invalid_json_data) { 'invalid json' }

        it 'logs an error' do
          expect(Rails.logger).to receive(:error).with(
            'RepresentationManagement::AccreditedIndividualsUpdate: Error processing job: unexpected character: ' \
            "'invalid json' at line 1 column 1"
          )

          subject.perform(invalid_json_data)
        end
      end

      context 'when the representative cannot be found' do
        let(:id) { 'not_found' }

        it 'logs an error' do
          expect(Rails.logger).to receive(:error).with(
            'RepresentationManagement::AccreditedIndividualsUpdate: Update failed for Rep id: not_found: ' \
            "Couldn't find AccreditedIndividual with 'id'=not_found"
          )

          subject.perform(json_data)
        end
      end

      context 'when changing the address' do
        let(:id) { SecureRandom.uuid }
        let!(:representative) { create_accredited_individual }

        it 'updates the address' do
          subject.perform(json_data)
          representative.reload

          expect(representative.send('address_line1')).to eq('37N 1st St')
        end
      end

      context 'address validation retries' do
        let(:id) { SecureRandom.uuid }
        let!(:representative) { create_accredited_individual }
        let(:validation_stub) { instance_double(VAProfile::V3::AddressValidation::Service) }
        let(:api_response_with_zero_v3) do
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
            allow(validation_stub).to receive(:candidate).and_return(api_response_with_zero_v3, api_response1_v3)
          end

          it 'does not update the representative address' do
            expect(representative.lat).to eq(39)
            expect(representative.long).to eq(-75)
            expect(representative.address_line1).to eq('123 East Main St')

            subject.perform(json_data)
            representative.reload

            expect(representative.lat).to eq(40.717029)
            expect(representative.long).to eq(-73.964956)
            expect(representative.address_line1).to eq('37N 1st St')
          end
        end

        context 'when the second retry has non-zero coordinates' do
          before do
            allow(VAProfile::V3::AddressValidation::Service).to receive(:new).and_return(validation_stub)
            allow(validation_stub).to receive(:candidate).and_return(api_response_with_zero_v3,
                                                                     api_response_with_zero_v3,
                                                                     api_response2_v3)
          end

          it 'does not update the representative address' do
            expect(representative.lat).to eq(39)
            expect(representative.long).to eq(-75)
            expect(representative.address_line1).to eq('123 East Main St')

            subject.perform(json_data)
            representative.reload

            expect(representative.lat).to eq(40.717029)
            expect(representative.long).to eq(-73.964956)
            expect(representative.address_line1).to eq('37N 2nd St')
          end
        end

        context 'when the third retry has non-zero coordinates' do
          before do
            allow(VAProfile::V3::AddressValidation::Service).to receive(:new).and_return(validation_stub)
            allow(validation_stub).to receive(:candidate).and_return(api_response_with_zero_v3,
                                                                     api_response_with_zero_v3,
                                                                     api_response_with_zero_v3,
                                                                     api_response3_v3)
          end

          it 'updates the representative address' do
            expect(representative.lat).to eq(39)
            expect(representative.long).to eq(-75)
            expect(representative.address_line1).to eq('123 East Main St')

            subject.perform(json_data)
            representative.reload

            expect(representative.lat).to eq(40.717029)
            expect(representative.long).to eq(-73.964956)
            expect(representative.address_line1).to eq('37N 3rd St')
          end
        end

        context 'when the retry coordinates are all zero' do
          before do
            allow(VAProfile::V3::AddressValidation::Service).to receive(:new).and_return(validation_stub)
            allow(validation_stub).to receive(:candidate).and_return(api_response_with_zero_v3,
                                                                     api_response_with_zero_v3,
                                                                     api_response_with_zero_v3,
                                                                     api_response_with_zero_v3)
          end

          it 'does not update the representative address' do
            expect(representative.lat).to eq(39)
            expect(representative.long).to eq(-75)
            expect(representative.address_line1).to eq('123 East Main St')

            subject.perform(json_data)
            representative.reload

            expect(representative.lat).to eq(39)
            expect(representative.long).to eq(-75)
            expect(representative.address_line1).to eq('123 East Main St')
          end
        end
      end
    end
  end
end
