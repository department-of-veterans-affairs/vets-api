# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::AddressValidationController, type: :controller do
  let(:user) { FactoryBot.build(:user) }
  let(:address) { build(:vet360_address) }

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
          post(:create, params: address.to_h)

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
        address.address_line1 = '5 Stoddard Ct'
        address.city = 'Sparks Glencoe'
        address.state_code = 'MD'
        address.zip_code = '21152'

        VCR.use_cassette(
          'vet360/address_validation/candidate_one_match',
          VCR::MATCH_EVERYTHING
        ) do
          post(:create, params: address.to_h)
          expect(JSON.parse(response.body)).to eq(
            [{"address"=>
             {"address_line1"=>"5 Stoddard Ct",
              "address_type"=>"DOMESTIC",
              "city"=>"Sparks Glencoe",
              "country_name"=>"USA",
              "country_code_iso3"=>"USA",
              "county_code"=>"24005",
              "county_name"=>"Baltimore",
              "state_code"=>"MD",
              "zip_code"=>"21152",
              "zip_code_suffix"=>"9367"},
            "address_meta_data"=>
             {"confidence_score"=>100.0,
              "address_type"=>"Domestic",
              "delivery_point_validation"=>"CONFIRMED",
              "residential_delivery_indicator"=>"RESIDENTIAL",
              "validation_key"=>-2025296286}}]
          )
        end
      end
    end
  end
end
