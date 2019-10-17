# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::AddressValidationController, type: :controller do
  let(:user) { FactoryBot.build(:user) }
  let(:address) { build(:vet360_address) }
  let(:multiple_match_addr) do
    build(:vet360_address, :multiple_matches)
  end

  before(:each) do
    sign_in_as(user)
  end

  describe '#create' do
    context 'with an invalid address' do
      it 'should return an error' do
        address.address_line1 = 'sdfdsfsdf'

        VCR.use_cassette(
          'vet360/address_validation/validate_no_match',
          VCR::MATCH_EVERYTHING
        ) do
          post(:create, params: { address: address.to_h })

          expect(JSON.parse(response.body)).to eq(
            {"errors"=>
              [{"title"=>"Address Validation Error",
                "detail"=>
                 {"address"=>
                   {"state_province"=>{"name"=>"District Of Colunbia", "code"=>"DC"},
                    "country"=>{"name"=>"USA", "code"=>"USA", "fips_code"=>"US", "iso2_code"=>"US", "iso3_code"=>"USA"},
                    "address_line1"=>"Sdfdsfsdf",
                    "city"=>"Washington",
                    "zip_code5"=>"20011"},
                  "geocode"=>{"calc_date"=>"2019-10-15T07:21:23+00:00", "location_precision"=>0.0, "latitude"=>38.9525, "longitude"=>-77.0202},
                  "address_meta_data"=>
                   {"confidence_score"=>0.0, "address_type"=>"Unknown", "delivery_point_validation"=>"MISSING_ZIP", "validation_key"=>1008171488},
                  "messages"=>[{"code"=>"ADDRVAL112", "key"=>"AddressCouldNotBeFound", "severity"=>"ERROR", "text"=>"The Address could not be found"}]},
                "code"=>"VET360_AV_ERROR",
                "status"=>"400"}]}
          )
          expect(response.status).to eq(400)
        end
      end
    end

    context 'with a found address' do
      it 'should return suggested addresses for a given address' do
        VCR.use_cassette(
          'vet360/address_validation/validate_match',
          VCR::MATCH_EVERYTHING
        ) do
          VCR.use_cassette(
            'vet360/address_validation/candidate_multiple_matches',
            VCR::MATCH_EVERYTHING
          ) do
            post(:create, params: { address: multiple_match_addr.to_h })
            expect(JSON.parse(response.body)).to eq(
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
            expect(response.status).to eq(200)
          end
        end
      end
    end
  end
end
