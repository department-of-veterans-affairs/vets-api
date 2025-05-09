# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/v3/address_validation/service'

describe VAProfile::V3::AddressValidation::Service do
  let(:base_address) { build(:va_profile_v3_validation_address) }

  let(:address) do
    base_address.address_line1 = '5 Stoddard Ct'
    base_address.city = 'Sparks Glencoe'
    base_address.state_code = 'MD'
    base_address.zip_code = '21152'

    base_address
  end

  let(:invalid_address) do
    base_address.address_line1 = 'sdfdsfsdf'
    base_address.city = 'Sparks Glencoe'
    base_address.state_code = 'MD'
    base_address.zip_code = '21152'
    base_address
  end

  let(:multiple_match_addr) do
    build(:va_profile_v3_validation_address, :multiple_matches)
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
  end

  describe '#address_suggestions' do
    context 'with a found address' do
      it 'returns suggested addresses' do
        VCR.use_cassette(
          'va_profile/v3/address_validation/candidate_multiple_matches',
          VCR::MATCH_EVERYTHING
        ) do
          res = described_class.new.address_suggestions(multiple_match_addr)
          expect(JSON.parse(res.to_json)).to eq(
            'addresses' => [
              {
                'address' => {
                  'address_line1' => '37 N 1st St',
                  'address_type' => 'DOMESTIC',
                  'city' => 'Brooklyn',
                  'country_name' => 'United States',
                  'country_code_iso3' => 'USA',
                  'county_code' => '36047',
                  'county_name' => 'Kings',
                  'state_code' => 'NY',
                  'zip_code' => '11249',
                  'zip_code_suffix' => '3939'
                },
                'address_meta_data' => {
                  'confidence_score' => 100.0,
                  'address_type' => 'Domestic',
                  'delivery_point_validation' => 'UNDELIVERABLE'
                }
              },
              {
                'address' => {
                  'address_line1' => '37 S 1st St',
                  'address_type' => 'DOMESTIC',
                  'city' => 'Brooklyn',
                  'country_name' => 'United States',
                  'country_code_iso3' => 'USA',
                  'county_code' => '36047',
                  'county_name' => 'Kings',
                  'state_code' => 'NY',
                  'zip_code' => '11249',
                  'zip_code_suffix' => '4101'
                },
                'address_meta_data' => {
                  'confidence_score' => 100.0,
                  'address_type' => 'Domestic',
                  'delivery_point_validation' => 'CONFIRMED'
                }
              }
            ],
            'override_validation_key' => '-646932106',
            'validation_key' => '-646932106'
          )
        end
      end
    end
  end

  describe '#candidate' do
    context 'with a request error' do
      it 'raises backend service exception' do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(Common::Client::Errors::ClientError)
        expect { described_class.new.candidate(invalid_address) }.to raise_error(
          Common::Exceptions::BackendServiceException
        )
      end
    end

    context 'with an invalid address' do
      it 'returns error messages' do
        VCR.use_cassette(
          'va_profile/v3/address_validation/candidate_no_match',
          VCR::MATCH_EVERYTHING
        ) do
          expect(described_class.new.candidate(invalid_address)).to eq(
            'candidate_addresses' => [
              {
                'address_line1' => 'Sdfdsfsdf',
                'city_name' => 'Sparks Glencoe',
                'zip_code5' => '21152',
                'state' => {
                  'state_name' => 'Maryland',
                  'state_code' => 'MD'
                },
                'country' => {
                  'country_name' => 'United States',
                  'country_code_fips' => 'US',
                  'country_code_iso2' => 'US',
                  'country_code_iso3' => 'USA'
                },
                'geocode' => {
                  'calc_date' => '2024-10-22T19:26:20+00:00Z',
                  'latitude' => 39.5412,
                  'longitude' => -76.6676
                },
                'confidence' => 0.0,
                'address_type' => 'Domestic',
                'delivery_point_validation' => 'MISSING_ZIP'
              }
            ],
            'override_validation_key' => 1_499_210_293,
            'messages' => [
              {
                'code' => 'ADDRVAL108',
                'key' => 'CandidateAddressNotFound',
                'severity' => 'WARN',
                'text' => 'No Candidate Address Found',
                'potentially_self_correcting_on_retry' => true
              }
            ]
          )
        end
      end
    end

    context 'with a found address' do
      context 'with multiple matches' do
        it 'returns suggested addresses for a given address' do
          VCR.use_cassette(
            'va_profile/v3/address_validation/candidate_multiple_matches',
            VCR::MATCH_EVERYTHING
          ) do
            res = described_class.new.candidate(multiple_match_addr)
            expect(res).to eq(
              'candidate_addresses' => [
                {
                  'address_line1' => '37 N 1st St',
                  'city_name' => 'Brooklyn',
                  'zip_code5' => '11249',
                  'zip_code4' => '3939',
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
                  'address_pou' => 'RESIDENCE',
                  'geocode' => {
                    'calc_date' => '2024-10-18T18:16:23.870Z',
                    'location_precision' => 31.0,
                    'latitude' => 40.717029,
                    'longitude' => -73.964956
                  },
                  'confidence' => 100.0,
                  'address_type' => 'Domestic',
                  'delivery_point_validation' => 'UNDELIVERABLE'
                },
                {
                  'address_line1' => '37 S 1st St',
                  'city_name' => 'Brooklyn',
                  'zip_code5' => '11249',
                  'zip_code4' => '4101',
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
                    'country_code_iso2' => 'US',
                    'country_code_fips' => 'US',
                    'country_code_iso3' => 'USA'
                  },
                  'address_pou' => 'RESIDENCE',
                  'geocode' => {
                    'calc_date' => '2024-10-18T18:16:23.870Z',
                    'location_precision' => 31.0,
                    'latitude' => 40.715367,
                    'longitude' => -73.965369
                  },
                  'confidence' => 100.0,
                  'address_type' => 'Domestic',
                  'delivery_point_validation' => 'CONFIRMED'
                }
              ],
              'override_validation_key' => '-646932106'
            )
          end
        end
      end
    end
  end
end
