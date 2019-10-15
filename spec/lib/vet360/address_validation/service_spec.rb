# frozen_string_literal: true

require 'rails_helper'

describe Vet360::AddressValidation::Service do
  let(:base_address) { build(:vet360_address) }

  let(:address) do
    base_address.address_line1 = '5 Stoddard Ct'
    base_address.city = 'Sparks Glencoe'
    base_address.state_code = 'MD'
    base_address.zip_code = '21152'

    base_address
  end

  let(:invalid_address) do
    base_address.address_line1 = 'sdfdsfsdf'
    base_address
  end

  let(:multiple_match_addr) do
    base_address.address_line1 = '37 1st st'
    base_address.city = 'Brooklyn'
    base_address.state_code = 'NY'
    base_address.zip_code = '11249'

    base_address
  end

  describe '#address_suggestions' do
    context 'with a found address' do
      it 'should return suggested addresses' do
        VCR.use_cassette(
          'vet360/address_validation/validate_match',
          VCR::MATCH_EVERYTHING
        ) do
          VCR.use_cassette(
            'vet360/address_validation/candidate_multiple_matches',
            VCR::MATCH_EVERYTHING
          ) do
            res = described_class.new.address_suggestions(multiple_match_addr)
            expect(JSON.parse(res.to_json)).to eq(
              {"addresses"=>
                [{"address"=>
                   {"address_line1"=>"37 N 1st St",
                    "address_type"=>"DOMESTIC",
                    "city"=>"Brooklyn",
                    "country_name"=>"USA",
                    "country_code_iso3"=>"USA",
                    "county_code"=>"36047",
                    "county_name"=>"Kings",
                    "state_code"=>"NY",
                    "zip_code"=>"11249",
                    "zip_code_suffix"=>"3939"},
                  "address_meta_data"=>{"confidence_score"=>100.0, "address_type"=>"Domestic", "delivery_point_validation"=>"UNDELIVERABLE"}},
                 {"address"=>
                   {"address_line1"=>"37 S 1st St",
                    "address_type"=>"DOMESTIC",
                    "city"=>"Brooklyn",
                    "country_name"=>"USA",
                    "country_code_iso3"=>"USA",
                    "county_code"=>"36047",
                    "county_name"=>"Kings",
                    "state_code"=>"NY",
                    "zip_code"=>"11249",
                    "zip_code_suffix"=>"4101"},
                  "address_meta_data"=>
                   {"confidence_score"=>100.0, "address_type"=>"Domestic", "delivery_point_validation"=>"CONFIRMED", "residential_delivery_indicator"=>"MIXED"}}],
               "validation_key"=>609319007}
            )
          end
        end
      end
    end
  end

  describe '#validate' do
    context 'with an invalid address' do
      it 'should return an error' do
        VCR.use_cassette(
          'vet360/address_validation/validate_no_match',
          VCR::MATCH_EVERYTHING
        ) do
          expect { described_class.new.validate(invalid_address) }.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end

    context 'with a found address' do
      it 'should return suggested address' do
        VCR.use_cassette(
          'vet360/address_validation/validate_match',
          VCR::MATCH_EVERYTHING
        ) do
          described_class.new.validate(multiple_match_addr)
        end
      end
    end
  end

  describe '#candidate' do
    context 'with an invalid address' do
      it 'should return an error' do
        VCR.use_cassette(
          'vet360/address_validation/candidate_no_match',
          VCR::MATCH_EVERYTHING
        ) do
          expect { described_class.new.candidate(invalid_address) }.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end

    context 'with a found address' do
      context 'with multiple matches' do
        it 'should return suggested addresses for a given address' do
          VCR.use_cassette(
            'vet360/address_validation/candidate_multiple_matches',
            VCR::MATCH_EVERYTHING
          ) do
            res = described_class.new.candidate(multiple_match_addr)
            expect(res).to eq(
              {"candidate_addresses"=>
                [{"address"=>
                   {"county"=>{"name"=>"Kings", "county_fips_code"=>"36047"},
                    "state_province"=>{"name"=>"New York", "code"=>"NY"},
                    "country"=>{"name"=>"USA", "code"=>"USA", "fips_code"=>"US", "iso2_code"=>"US", "iso3_code"=>"USA"},
                    "address_line1"=>"37 N 1st St",
                    "city"=>"Brooklyn",
                    "zip_code5"=>"11249",
                    "zip_code4"=>"3939"},
                  "geocode"=>{"calc_date"=>"2019-10-14T11:21:44+00:00", "location_precision"=>31.0, "latitude"=>40.717018, "longitude"=>-73.964935},
                  "address_meta_data"=>
                   {"confidence_score"=>100.0, "address_type"=>"Domestic", "delivery_point_validation"=>"UNDELIVERABLE", "validation_key"=>-1384531381}},
                 {"address"=>
                   {"county"=>{"name"=>"Kings", "county_fips_code"=>"36047"},
                    "state_province"=>{"name"=>"New York", "code"=>"NY"},
                    "country"=>{"name"=>"USA", "code"=>"USA", "fips_code"=>"US", "iso2_code"=>"US", "iso3_code"=>"USA"},
                    "address_line1"=>"37 S 1st St",
                    "city"=>"Brooklyn",
                    "zip_code5"=>"11249",
                    "zip_code4"=>"4101"},
                  "geocode"=>{"calc_date"=>"2019-10-14T11:21:44+00:00", "location_precision"=>31.0, "latitude"=>40.715383, "longitude"=>-73.965421},
                  "address_meta_data"=>
                   {"confidence_score"=>100.0,
                    "address_type"=>"Domestic",
                    "delivery_point_validation"=>"CONFIRMED",
                    "residential_delivery_indicator"=>"MIXED",
                    "validation_key"=>2017396678}}]}
            )
          end
        end
      end

      it 'should return suggested addresses for a given address' do
        VCR.use_cassette(
          'vet360/address_validation/candidate_one_match',
          VCR::MATCH_EVERYTHING
        ) do
          res = described_class.new.candidate(address)
          expect(res).to eq(
            {"candidate_addresses"=>
              [{"address"=>
                 {"county"=>{"name"=>"Baltimore", "county_fips_code"=>"24005"},
                  "state_province"=>{"name"=>"Maryland", "code"=>"MD"},
                  "country"=>{"name"=>"USA", "code"=>"USA", "fips_code"=>"US", "iso2_code"=>"US", "iso3_code"=>"USA"},
                  "address_line1"=>"5 Stoddard Ct",
                  "city"=>"Sparks Glencoe",
                  "zip_code5"=>"21152",
                  "zip_code4"=>"9367"},
                "geocode"=>{"calc_date"=>"2019-10-10T10:40:08+00:00", "location_precision"=>31.0, "latitude"=>39.532499, "longitude"=>-76.647183},
                "address_meta_data"=>
                 {"confidence_score"=>100.0,
                  "address_type"=>"Domestic",
                  "delivery_point_validation"=>"CONFIRMED",
                  "residential_delivery_indicator"=>"RESIDENTIAL",
                  "validation_key"=>-2025296286}}]}
          )
        end
      end
    end
  end
end
