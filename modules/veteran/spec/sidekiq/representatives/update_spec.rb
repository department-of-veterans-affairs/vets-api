# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Representatives::Update do
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
            state_province: {
              code: 'abc'
            },
            zip_code5: 'abc',
            zip_code4: 'abc',
            country_code_iso3: 'abc'
          },
          email: 'test@example.com',
          phone_number: '999-999-9999',
          address_changed:,
          email_changed: false,
          phone_number_changed: false
        }
      ].to_json
    end
    let(:api_response) do
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
      allow_any_instance_of(VAProfile::AddressValidation::Service).to receive(:candidate).and_return(api_response)
    end

    context 'when JSON parsing fails' do
      let(:invalid_json_data) { 'invalid json' }

      it 'logs an error to Sentry' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(
          "Representatives::Update: Error processing job: unexpected token at 'invalid json'", :error
        )

        subject.perform(invalid_json_data)
      end
    end

    context 'when updating a representative' do
      let(:id) { '123abc' }
      let(:address_changed) { true }
      let!(:representative) do
        create(:representative,
               representative_id: '123abc',
               first_name: 'Bob',
               last_name: 'Law',
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
               email: 'email@example.com',
               location: 'POINT(-75 39)',
               phone_number: '111-111-1111')
      end

      before do
        Veteran::FlaggedVeteranRepresentativeContactData.create(
          ip_address: '192.168.1.1',
          representative_id: id,
          flag_type: 'address',
          flagged_value: 'flagged_value'
        )
        Veteran::FlaggedVeteranRepresentativeContactData.create(
          ip_address: '192.168.1.2',
          representative_id: id,
          flag_type: 'address',
          flagged_value: 'flagged_value'
        )
      end

      context 'when address_changed is true and address is valid' do
        it 'updates the address and updates associated flagged records' do
          flagged_records = Veteran::FlaggedVeteranRepresentativeContactData.where(representative_id: id, flag_type: 'address')

          flagged_records.each do |record|
            expect(record.flagged_value_updated_at).to be_nil
          end

          subject.perform(json_data)

          representative.reload

          expect(representative.address_line1).to eq('37N 1st St')
          expect(representative.address_line2).to be_nil
          expect(representative.address_line3).to be_nil
          expect(representative.address_type).to eq('Domestic')
          expect(representative.city).to eq('Brooklyn')
          expect(representative.country_code_iso3).to eq('USA')
          expect(representative.country_name).to eq('United States')
          expect(representative.county_name).to eq('Kings')
          expect(representative.county_code).to eq('36047')
          expect(representative.province).to eq('New York')
          expect(representative.state_code).to eq('NY')
          expect(representative.zip_code).to eq('11249')
          expect(representative.zip_suffix).to eq('3939')
          expect(representative.lat).to eq(40.717029)
          expect(representative.long).to eq(-73.964956)
          expect(representative.location.x).to eq(-73.964956)
          expect(representative.location.y).to eq(40.717029)
          expect(representative.email).to eq('test@example.com')
          expect(representative.phone_number).to eq('999-999-9999')

          flagged_records.each do |record|
            record.reload
            expect(record.flagged_value_updated_at).to_not be_nil
          end
        end
      end

      context 'when address_changed is true and address is not valid' do
        let(:api_response) { { 'candidateAddresses' => [] } }

        it 'does not update the address record' do
          subject.perform(json_data)

          representative.reload
          expect(representative.address_line1).to eq('123 East Main St')
        end
      end

      context 'when the representative cannot be found' do
        let(:id) { 'not_found' }

        it 'logs an error to Sentry' do
          expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(
            'Representatives::Update: Update failed for Rep id: not_found: uncaught throw StandardError', :error
          )

          subject.perform(json_data)
        end
      end
    end
  end
end
