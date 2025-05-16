# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'a representative email or phone update process' do |flag_type, attribute, valid_value, _invalid_value| # rubocop:disable Layout/LineLength
  let(:id) { '123abc' }
  let(:address_changed) { flag_type == 'address' }
  let(:email_changed) { flag_type == 'email' }
  let(:phone_number_changed) { flag_type == 'phone_number' }
  let!(:representative) { create_representative }

  context 'when address_exists is true' do
    let(:address_exists) { true }

    before do
      allow(Flipper).to receive(:enabled?).with(:remove_pciu).and_return(true)
      create_flagged_records(flag_type)
      allow(VAProfile::V3::AddressValidation::Service).to receive(:new).and_return(double('VAProfile::V3::AddressValidation::Service', candidate: nil)) # rubocop:disable Layout/LineLength
    end

    it "updates the #{flag_type} and the associated flagged records" do
      flagged_records =
        RepresentationManagement::FlaggedVeteranRepresentativeContactData
        .where(representative_id: id, flag_type:)

      flagged_records.each do |record|
        expect(record.flagged_value_updated_at).to be_nil
      end

      subject.perform(json_data)
      representative.reload

      expect(representative.send(attribute)).to eq(valid_value)

      flagged_records.each do |record|
        record.reload
        expect(record.flagged_value_updated_at).not_to be_nil
      end
    end

    it 'does not call validate_address or VAProfile::V3::AddressValidation::Service.new' do
      subject.perform(json_data)

      expect(VAProfile::V3::AddressValidation::Service).not_to have_received(:new)
    end
  end
end

RSpec.describe Representatives::Update do
  # rubocop:disable Metrics/MethodLength
  def create_representative
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
  # rubocop:enable Metrics/MethodLength

  def create_flagged_records(flag_type)
    2.times do |n|
      RepresentationManagement::FlaggedVeteranRepresentativeContactData.create(
        ip_address: "192.168.1.#{n + 1}",
        representative_id: '123abc',
        flag_type:,
        flagged_value: 'flagged_value'
      )
    end
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
          phone_number: '999-999-9999',
          address_exists:,
          address_changed:,
          email_changed:,
          phone_number_changed:
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
          "Representatives::Update: Error processing job: unexpected character: 'invalid json' at line 1 column 1"
        )

        subject.perform(invalid_json_data)
      end
    end

    context 'when the representative cannot be found' do
      let(:id) { 'not_found' }
      let(:address_exists) { false }
      let(:address_changed) { true }
      let(:email_changed) { false }
      let(:phone_number_changed) { false }

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with(
          'Representatives::Update: Update failed for Rep id: not_found: Representative not found.'
        )

        subject.perform(json_data)
      end
    end

    context 'when address_exists is true and address_changed is true' do
      let(:id) { '123abc' }
      let(:address_exists) { true }
      let(:address_changed) { true }
      let(:email_changed) { false }
      let(:phone_number_changed) { false }
      let!(:representative) { create_representative }

      before do
        create_flagged_records('address')
      end

      it 'updates the address and the associated flagged records' do
        flagged_records =
          RepresentationManagement::FlaggedVeteranRepresentativeContactData
          .where(representative_id: id, flag_type: 'address')

        flagged_records.each do |record|
          expect(record.flagged_value_updated_at).to be_nil
        end

        subject.perform(json_data)
        representative.reload

        expect(representative.send('address_line1')).to eq('37N 1st St')

        flagged_records.each do |record|
          record.reload
          expect(record.flagged_value_updated_at).not_to be_nil
        end
      end
    end

    context 'when address_exists is false and address_changed is true' do
      let(:id) { '123abc' }
      let(:address_exists) { false }
      let(:address_changed) { true }
      let(:email_changed) { false }
      let(:phone_number_changed) { false }
      let!(:representative) { create_representative }

      before do
        create_flagged_records('address')
      end

      it 'updates the address and the associated flagged records' do
        flagged_records =
          RepresentationManagement::FlaggedVeteranRepresentativeContactData
          .where(representative_id: id, flag_type: 'address')

        flagged_records.each do |record|
          expect(record.flagged_value_updated_at).to be_nil
        end

        subject.perform(json_data)
        representative.reload

        expect(representative.send('address_line1')).to eq('37N 1st St')

        flagged_records.each do |record|
          record.reload
          expect(record.flagged_value_updated_at).not_to be_nil
        end
      end
    end

    context 'when address_changed and email_changed is true' do
      let(:id) { '123abc' }
      let(:address_exists) { false }
      let(:address_changed) { true }
      let(:email_changed) { true }
      let(:phone_number_changed) { false }
      let!(:representative) { create_representative }

      before do
        create_flagged_records('address')
      end

      it 'updates the address and email and the associated flagged records' do
        flagged_address_records =
          RepresentationManagement::FlaggedVeteranRepresentativeContactData
          .where(representative_id: id, flag_type: 'address')
        flagged_email_records =
          RepresentationManagement::FlaggedVeteranRepresentativeContactData
          .where(representative_id: id, flag_type: 'email')
        flagged_email_records.each do |record|
          expect(record.flagged_value_updated_at).to be_nil
        end

        subject.perform(json_data)
        representative.reload
        expect(representative.send('address_line1')).to eq('37N 1st St')
        expect(representative.send('email')).to eq('test@example.com')

        flagged_address_records + flagged_email_records.each do |record|
          record.reload
          expect(record.flagged_value_updated_at).not_to be_nil
        end
      end
    end

    context "when updating a representative's email" do
      it_behaves_like 'a representative email or phone update process', 'email', :email, 'test@example.com',
                      'email@example.com'
    end

    context "when updating a representative's phone number" do
      it_behaves_like 'a representative email or phone update process', 'phone_number', :phone_number, '999-999-9999',
                      '111-111-1111'
    end

    context 'address validation retries' do
      let(:id) { '123abc' }
      let(:address_exists) { true }
      let(:address_changed) { true }
      let(:email_changed) { false }
      let(:phone_number_changed) { false }
      let!(:representative) { create_representative }
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
    # rubocop:disable Metrics/MethodLength
    def create_representative
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
    # rubocop:enable Metrics/MethodLength

    def create_flagged_records(flag_type)
      2.times do |n|
        RepresentationManagement::FlaggedVeteranRepresentativeContactData.create(
          ip_address: "192.168.1.#{n + 1}",
          representative_id: '123abc',
          flag_type:,
          flagged_value: 'flagged_value'
        )
      end
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
            phone_number: '999-999-9999',
            address_exists:,
            address_changed:,
            email_changed:,
            phone_number_changed:
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
            "Representatives::Update: Error processing job: unexpected character: 'invalid json' at line 1 column 1"
          )

          subject.perform(invalid_json_data)
        end
      end

      context 'when the representative cannot be found' do
        let(:id) { 'not_found' }
        let(:address_exists) { false }
        let(:address_changed) { true }
        let(:email_changed) { false }
        let(:phone_number_changed) { false }

        it 'logs an error' do
          expect(Rails.logger).to receive(:error).with(
            'Representatives::Update: Update failed for Rep id: not_found: Representative not found.'
          )

          subject.perform(json_data)
        end
      end

      context 'when address_exists is true and address_changed is true' do
        let(:id) { '123abc' }
        let(:address_exists) { true }
        let(:address_changed) { true }
        let(:email_changed) { false }
        let(:phone_number_changed) { false }
        let!(:representative) { create_representative }

        before do
          create_flagged_records('address')
        end

        it 'updates the address and the associated flagged records' do
          flagged_records =
            RepresentationManagement::FlaggedVeteranRepresentativeContactData
            .where(representative_id: id, flag_type: 'address')

          flagged_records.each do |record|
            expect(record.flagged_value_updated_at).to be_nil
          end

          subject.perform(json_data)
          representative.reload

          expect(representative.send('address_line1')).to eq('37N 1st St')

          flagged_records.each do |record|
            record.reload
            expect(record.flagged_value_updated_at).not_to be_nil
          end
        end
      end

      context 'when address_exists is false and address_changed is true' do
        let(:id) { '123abc' }
        let(:address_exists) { false }
        let(:address_changed) { true }
        let(:email_changed) { false }
        let(:phone_number_changed) { false }
        let!(:representative) { create_representative }

        before do
          create_flagged_records('address')
        end

        it 'updates the address and the associated flagged records' do
          flagged_records =
            RepresentationManagement::FlaggedVeteranRepresentativeContactData
            .where(representative_id: id, flag_type: 'address')

          flagged_records.each do |record|
            expect(record.flagged_value_updated_at).to be_nil
          end

          subject.perform(json_data)
          representative.reload

          expect(representative.send('address_line1')).to eq('37N 1st St')

          flagged_records.each do |record|
            record.reload
            expect(record.flagged_value_updated_at).not_to be_nil
          end
        end
      end

      context 'when address_changed and email_changed is true' do
        let(:id) { '123abc' }
        let(:address_exists) { false }
        let(:address_changed) { true }
        let(:email_changed) { true }
        let(:phone_number_changed) { false }
        let!(:representative) { create_representative }

        before do
          create_flagged_records('address')
        end

        it 'updates the address and email and the associated flagged records' do
          flagged_address_records =
            RepresentationManagement::FlaggedVeteranRepresentativeContactData
            .where(representative_id: id, flag_type: 'address')
          flagged_email_records =
            RepresentationManagement::FlaggedVeteranRepresentativeContactData
            .where(representative_id: id, flag_type: 'email')
          flagged_email_records.each do |record|
            expect(record.flagged_value_updated_at).to be_nil
          end

          subject.perform(json_data)
          representative.reload
          expect(representative.send('address_line1')).to eq('37N 1st St')
          expect(representative.send('email')).to eq('test@example.com')

          flagged_address_records + flagged_email_records.each do |record|
            record.reload
            expect(record.flagged_value_updated_at).not_to be_nil
          end
        end
      end

      context "when updating a representative's email" do
        it_behaves_like 'a representative email or phone update process', 'email', :email, 'test@example.com',
                        'email@example.com'
      end

      context "when updating a representative's phone number" do
        it_behaves_like 'a representative email or phone update process', 'phone_number', :phone_number, '999-999-9999',
                        '111-111-1111'
      end

      context 'address validation retries' do
        let(:id) { '123abc' }
        let(:address_exists) { true }
        let(:address_changed) { true }
        let(:email_changed) { false }
        let(:phone_number_changed) { false }
        let!(:representative) { create_representative }
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
