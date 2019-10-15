# frozen_string_literal: true

require 'rails_helper'

describe Vet360::AddressValidation::Service do
  let(:address) do
    address = build(:vet360_address)
    address.address_line1 = '5 Stoddard Ct'
    address.city = 'Sparks Glencoe'
    address.state_code = 'MD'
    address.zip_code = '21152'
    address
  end

  let(:invalid_address) do
    address = build(:vet360_address)
    address.address_line1 = 'sdfdsfsdf'
    address
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
          address.address_line1 = '37 1st st'
          address.city = 'Brooklyn'
          address.state_code = 'NY'
          address.zip_code = '11249'

          VCR.use_cassette(
            'vet360/address_validation/candidate_multiple_matches',
            VCR::MATCH_EVERYTHING
          ) do
            res = described_class.new.candidate(address)

            expect(JSON.parse(res.to_json)).to eq(
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
              "address_meta_data"=>
               {"confidence_score"=>100.0, "address_type"=>"Domestic", "delivery_point_validation"=>"UNDELIVERABLE", "validation_key"=>-1384531381}},
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
               {"confidence_score"=>100.0,
                "address_type"=>"Domestic",
                "delivery_point_validation"=>"CONFIRMED",
                "residential_delivery_indicator"=>"MIXED",
                "validation_key"=>2017396678}}]
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
