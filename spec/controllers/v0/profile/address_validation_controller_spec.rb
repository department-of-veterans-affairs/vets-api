# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::AddressValidationController, type: :controller do
  let(:user) { FactoryBot.build(:user) }
  let(:address) { build(:vet360_address) }
  let(:multiple_match_addr) do
    build(:vet360_address, :multiple_matches)
  end

  before do
    sign_in_as(user)
  end

  describe '#create' do
    context 'with an invalid address' do
      it 'returns an error' do
        post(:create, params: { address: build(:vet360_validation_address).to_h })

        expect(response.code).to eq('422')
        expect(JSON.parse(response.body)).to eq(
          {"errors"=>
            [{"title"=>"Address line1 can't be blank", "detail"=>"address-line1 - can't be blank", "code"=>"100", "source"=>{"pointer"=>"data/attributes/address-line1"}, "status"=>"422"},
             {"title"=>"City can't be blank", "detail"=>"city - can't be blank", "code"=>"100", "source"=>{"pointer"=>"data/attributes/city"}, "status"=>"422"},
             {"title"=>"State code can't be blank", "detail"=>"state-code - can't be blank", "code"=>"100", "source"=>{"pointer"=>"data/attributes/state-code"}, "status"=>"422"},
             {"title"=>"Zip code can't be blank", "detail"=>"zip-code - can't be blank", "code"=>"100", "source"=>{"pointer"=>"data/attributes/zip-code"}, "status"=>"422"}]}
        )
      end
    end

    context 'with a found address' do
      it 'returns suggested addresses for a given address' do
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
                    "country_name"=>"United States",
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
                    "country_name"=>"United States",
                    "country_code_iso3"=>"USA",
                    "county_code"=>"36047",
                    "county_name"=>"Kings",
                    "state_code"=>"NY",
                    "zip_code"=>"11249",
                    "zip_code_suffix"=>"4101"},
                  "address_meta_data"=>{"confidence_score"=>100.0, "address_type"=>"Domestic", "delivery_point_validation"=>"CONFIRMED", "residential_delivery_indicator"=>"MIXED"}}],
               "validation_key"=>-646932106}
            )
            expect(response.status).to eq(200)
          end
        end
      end
    end
  end
end
