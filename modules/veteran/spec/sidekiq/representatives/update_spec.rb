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
      create_flagged_records(flag_type)
      allow(VAProfile::AddressValidation::V3::Service).to receive(:new).and_return(double('VAProfile::AddressValidation::V3::Service', candidate: nil)) # rubocop:disable Layout/LineLength
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

    it 'does not call validate_address or VAProfile::AddressValidation::V3::Service.new' do
      subject.perform(json_data)

      expect(VAProfile::AddressValidation::V3::Service).not_to have_received(:new)
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
      validation_service = VAProfile::AddressValidation::V3::Service
      allow_any_instance_of(validation_service).to receive(:candidate).and_return(api_response_v3)
    end

    context 'when JSON parsing fails' do
      let(:invalid_json_data) { 'invalid json' }

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with(
          "Representatives::Update: Error processing job: unexpected character: 'invalid' at line 1 column 1"
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
          a_string_matching(/Representatives::Update:.*not_found.*Representative not found/)
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
      let(:validation_stub) { instance_double(VAProfile::AddressValidation::V3::Service) }
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
          allow(VAProfile::AddressValidation::V3::Service).to receive(:new).and_return(validation_stub)
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
          allow(VAProfile::AddressValidation::V3::Service).to receive(:new).and_return(validation_stub)
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
          allow(VAProfile::AddressValidation::V3::Service).to receive(:new).and_return(validation_stub)
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
          allow(VAProfile::AddressValidation::V3::Service).to receive(:new).and_return(validation_stub)
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

      context 'when initial validation raises CandidateAddressNotFound (ADDRVAL108)' do
        let(:id) { '123abc' }
        let(:address_exists) { true }
        let(:address_changed) { true }
        let(:email_changed) { false }
        let(:phone_number_changed) { false }
        let!(:representative) { create_representative }
        let(:validation_stub) { instance_double(VAProfile::AddressValidation::V3::Service) }

        let(:candidate_not_found_exception) do
          Common::Exceptions::BackendServiceException.new(
            'VET360_AV_ERROR',
            {
              detail: {
                'messages' => [
                  {
                    'code' => 'ADDRVAL108',
                    'key' => 'CandidateAddressNotFound',
                    'text' => 'No Candidate Address Found',
                    'severity' => 'INFO'
                  }
                ]
              },
              code: 'VET360_AV_ERROR'
            },
            400,
            nil
          )
        end

        before do
          allow(VAProfile::AddressValidation::V3::Service).to receive(:new).and_return(validation_stub)
          call_count = 0
          allow(validation_stub).to receive(:candidate) do
            if call_count.zero?
              call_count += 1
              raise candidate_not_found_exception
            else
              api_response1_v3 # successful retry response with valid non-zero coordinates
            end
          end
        end

        it 'retries after ADDRVAL108 and updates the representative address' do
          expect(representative.address_line1).to eq('123 East Main St')
          subject.perform(json_data)
          representative.reload
          expect(representative.address_line1).to eq('37N 1st St')
          expect(representative.lat).to eq(40.717029)
          expect(representative.long).to eq(-73.964956)
        end
      end

      context 'when all retries have failed' do
        it 'updates only email and phone' do
          service = Representatives::Update.new

          rep_double = instance_double(Veteran::Service::Representative)
          allow(Veteran::Service::Representative).to receive(:find_by).and_return(rep_double)

          # Make the validation service return nil (address validation failed)
          validation_stub = instance_double(VAProfile::AddressValidation::V3::Service, candidate: nil)
          allow(VAProfile::AddressValidation::V3::Service).to receive(:new).and_return(validation_stub)

          expect(rep_double).to receive(:update) do |attrs|
            # only email and phone_number should be present (raw_address handled in QueueUpdates)
            expect(attrs.keys.sort).to eq(%i[email phone_number])
            expect(attrs[:email]).to eq('new@example.com')
            expect(attrs[:phone_number]).to eq('555-555-5555')
            true
          end

          json = [
            {
              id: 'rep-1',
              address: {
                address_pou: 'RESIDENCE',
                address_line1: 'Unmatched Place',
                address_line2: nil,
                address_line3: nil,
                city: 'Some City',
                state: { state_code: 'ZZ' },
                zip_code5: '99999',
                zip_code4: nil,
                country_code_iso3: 'US'
              },
              raw_address: {
                'address_line1' => 'Unmatched Place',
                'address_line2' => nil,
                'address_line3' => nil,
                'city' => 'Some City',
                'state_code' => 'ZZ',
                'zip_code5' => '99999',
                'zip_code4' => nil
              },
              email: 'new@example.com',
              phone_number: '555-555-5555',
              address_exists: true,
              address_changed: true,
              email_changed: true,
              phone_number_changed: true
            }
          ].to_json

          service.perform(json)
        end
      end
    end

    context 'when spreadsheet has org + PO Box and preprocessing extracts PO Box' do
      let(:id) { '123abc' }
      let(:address_exists) { true }
      let(:address_changed) { true }
      let(:email_changed) { false }
      let(:phone_number_changed) { false }
      let!(:representative) { create_representative }
      let(:validation_stub) { instance_double(VAProfile::AddressValidation::V3::Service) }

      let(:org_po_address) do
        {
          'candidate_addresses' => [
            {
              'address_line1' => 'PO Box 25126',
              'address_line2' => 'DAV- VARO',
              'city_name' => 'Denver',
              'zip_code5' => '80225',
              'geocode' => { 'latitude' => 39.7486, 'longitude' => -104.9963 }
            }
          ]
        }
      end

      before do
        allow(VAProfile::AddressValidation::V3::Service).to receive(:new).and_return(validation_stub)
        # First validation attempt will be for original mixed line and we simulate failure (nil)
        allow(validation_stub).to receive(:candidate).and_return(nil, org_po_address)
      end

      it 'uses the preprocessor to extract PO Box and updates the representative' do
        # craft json_data with org on line1 and PO Box on line2
        rep_json = [
          {
            id:,
            address: {
              address_pou: 'RESIDENCE',
              address_line1: 'DAV- VARO PO Box 25126',
              address_line2: nil,
              address_line3: nil,
              city: 'Denver',
              state: { state_code: 'CO' },
              zip_code5: '80225',
              zip_code4: nil,
              country_code_iso3: 'US'
            },
            email: 'test@example.com',
            phone_number: '999-999-9999',
            address_exists:,
            address_changed:,
            email_changed:,
            phone_number_changed:
          }
        ].to_json

        subject.perform(rep_json)
        representative.reload

        expect(representative.address_line1).to eq('PO Box 25126')
        expect(representative.address_line2).to match(/DAV-? VARO/i)
        expect(representative.lat).to eq(39.7486)
        expect(representative.long).to eq(-104.9963)
      end
    end

    context 'when only email or phone changes (not address)' do
      let(:id) { '123abc' }
      let(:json_email_only) do
        [
          {
            id:,
            address: {
              address_pou: 'RESIDENCE',
              address_line1: '123 Original St',
              address_line2: nil,
              address_line3: nil,
              city: 'Original City',
              state: { state_code: 'CA' },
              zip_code5: '90210',
              zip_code4: nil,
              country_code_iso3: 'US'
            },
            raw_address: original_raw_address,
            email: 'newemail@example.com',
            phone_number: representative.phone_number,
            address_exists:,
            address_changed:,
            email_changed:,
            phone_number_changed:
          }
        ].to_json
      end
      let(:address_exists) { true }
      let(:address_changed) { false }
      let(:email_changed) { true }
      let(:phone_number_changed) { false }
      let!(:representative) { create_representative }

      let(:original_raw_address) do
        {
          'address_line1' => '123 Original St',
          'address_line2' => nil,
          'address_line3' => nil,
          'city' => 'Original City',
          'state_code' => 'CA',
          'zip_code' => '90210'
        }
      end

      before do
        representative.update(raw_address: original_raw_address)
      end

      it 'updates email without affecting address fields' do
        subject.perform(json_email_only)
        representative.reload

        expect(representative.email).to eq('newemail@example.com')
        expect(representative.address_line1).to eq('123 East Main St') # Original address unchanged
      end

      it 'does not trigger address validation for email-only changes' do
        validation_service = VAProfile::AddressValidation::V3::Service
        expect(validation_service).not_to receive(:new)

        subject.perform(json_email_only)
      end
    end

    context 'when address validation fails and geocoding jobs are enqueued' do
      let(:id) { '123abc' }
      let(:address_exists) { false }
      let(:address_changed) { true }
      let(:email_changed) { false }
      let(:phone_number_changed) { false }
      let!(:representative) { create_representative }
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

      before do
        validation_service = VAProfile::AddressValidation::V3::Service
        allow_any_instance_of(validation_service).to receive(:candidate).and_return(nil)
      end

      it 'enqueues a geocoding job with the correct parameters when validation fails' do
        expect(RepresentationManagement::GeocodeRepresentativeJob)
          .to receive(:perform_in).with(0.seconds, 'Veteran::Service::Representative', '123abc')

        subject.perform(json_data)
      end

      it 'tracks the representative_id for failed validations' do
        subject.perform(json_data)

        expect(subject.instance_variable_get(:@records_needing_geocoding)).to include('123abc')
      end

      context 'with multiple validation failures' do
        let(:json_data_multiple) do
          [
            {
              id: '123abc',
              address: { address_pou: 'abc', address_line1: 'abc', city_name: 'abc',
                         state: { state_code: 'abc' }, zip_code5: 'abc', country_code_iso3: 'abc' },
              email: 'test@example.com',
              phone_number: '999-999-9999',
              address_exists: false,
              address_changed: true,
              email_changed: false,
              phone_number_changed: false
            },
            {
              id: '456def',
              address: { address_pou: 'def', address_line1: 'def', city_name: 'def',
                         state: { state_code: 'def' }, zip_code5: 'def', country_code_iso3: 'def' },
              email: 'test2@example.com',
              phone_number: '888-888-8888',
              address_exists: false,
              address_changed: true,
              email_changed: false,
              phone_number_changed: false
            },
            {
              id: '789ghi',
              address: { address_pou: 'ghi', address_line1: 'ghi', city_name: 'ghi',
                         state: { state_code: 'ghi' }, zip_code5: 'ghi', country_code_iso3: 'ghi' },
              email: 'test3@example.com',
              phone_number: '777-777-7777',
              address_exists: false,
              address_changed: true,
              email_changed: false,
              phone_number_changed: false
            }
          ].to_json
        end

        before do
          create(:representative, representative_id: '456def')
          create(:representative, representative_id: '789ghi')
        end

        it 'enqueues multiple geocoding jobs with 2-second rate limiting' do
          expect(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).with(0.seconds, 'Veteran::Service::Representative', '123abc')
          expect(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).with(2.seconds, 'Veteran::Service::Representative', '456def')
          expect(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).with(4.seconds, 'Veteran::Service::Representative', '789ghi')

          subject.perform(json_data_multiple)
        end
      end

      context 'when geocoding job enqueue fails' do
        before do
          allow(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).and_raise(StandardError, 'Sidekiq error')
        end

        it 'logs an error and sends a Slack notification' do
          expect(Rails.logger).to receive(:error).with(
            a_string_matching(/Representatives::Update: Address validation failed for Rep: 123abc/)
          )
          expect(Rails.logger).to receive(:error).with(
            a_string_matching(/Representatives::Update: Error enqueueing geocoding jobs: Sidekiq error/)
          )

          subject.perform(json_data)

          expect(subject.slack_messages).to include(
            a_string_matching(/Error enqueueing geocoding jobs: Sidekiq error/)
          )
        end
      end
    end
  end
end
