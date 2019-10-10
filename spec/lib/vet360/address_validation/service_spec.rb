# frozen_string_literal: true

require 'rails_helper'

describe Vet360::AddressValidation::Service do
  let(:address) { build(:vet360_address) }

  describe '#candidate' do
    # TODO multiple suggestions
    # TODO business address
    context 'with an invalid address' do
      it 'should return an error' do
        address.address_line1 = 'sdfdsfsdf'

        VCR.use_cassette(
          'vet360/address_validation/candidate_no_match',
          VCR::MATCH_EVERYTHING
        ) do
          expect { described_class.new.candidate(address) }.to raise_error(Common::Exceptions::BackendServiceException)
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
          res = described_class.new.candidate(address)

          expect(JSON.parse(res.to_json)).to eq(
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
