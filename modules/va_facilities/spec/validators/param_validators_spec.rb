# frozen_string_literal: true

require 'spec_helper'
require 'rails_helper'

class DummyClass
  require_dependency 'va_facilities/param_validators'
  require_dependency 'common/exceptions/internal/invalid_field_value'
  require_dependency 'common/exceptions/internal/parameter_missing'

  include VaFacilities::ParamValidators
  attr_accessor :params

  def initialize(params = nil)
    @params = params
  end

  def render(format = nil)
    format
  end
end

RSpec.describe VaFacilities::ParamValidators do
  before(:each) do
    @dummy_class = DummyClass.new
  end

  describe 'zip validator' do
    it 'raises an exception when not valid numbers' do
      @dummy_class.params = { zip: 'five' }
      expect do
        @dummy_class.validate_zip
      end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
        expect(error.message).to eq 'Invalid field value'
      }
    end

    it 'raises an exception when too many numbers' do
      @dummy_class.params = { zip: '75075-23124' }
      expect do
        @dummy_class.validate_zip
      end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
        expect(error.message).to eq 'Invalid field value'
      }
    end

    it 'raises an exception when 5 digit zip not found in zcta' do
      @dummy_class.params = { zip: '00001' }
      expect do
        @dummy_class.validate_zip
      end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
        expect(error.message).to eq 'Invalid field value'
      }
    end

    it 'passes validation for 5 numbered zip' do
      @dummy_class.params = { zip: '75075' }
      expect(@dummy_class.validate_zip).to be_nil
    end

    it 'passes validation for extended numbered zip' do
      @dummy_class.params = { zip: '75075-3234' }
      expect(@dummy_class.validate_zip).to be_nil
    end
  end

  describe 'state code validation' do
    it 'raises an exception when not valid state code' do
      @dummy_class.params = { state: 'gg' }
      expect do
        @dummy_class.validate_state_code
      end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
        expect(error.message).to eq 'Invalid field value'
      }
    end

    it 'passes validation for state code' do
      @dummy_class.params = { state: 'TX' }
      expect(@dummy_class.validate_state_code).to be_nil
    end

    it 'passes validation for APO' do
      @dummy_class.params = { state: 'APO' }
      expect(@dummy_class.validate_state_code).to be_nil
    end

    it 'passes validation for Guam' do
      @dummy_class.params = { state: 'guam' }
      expect(@dummy_class.validate_state_code).to be_nil
    end
  end

  describe 'type with service validation' do
    it 'raises an exception when type is nil and service is not' do
      @dummy_class.params = { type: nil, services: 'service' }
      expect do
        @dummy_class.validate_no_services_without_type
      end.to raise_error(Common::Exceptions::ParameterMissing) { |error|
        expect(error.message).to eq 'Missing parameter'
      }
    end

    it 'raises an exception when type is not present and service is' do
      @dummy_class.params = { services: 'service' }
      expect do
        @dummy_class.validate_no_services_without_type
      end.to raise_error(Common::Exceptions::ParameterMissing) { |error|
        expect(error.message).to eq 'Missing parameter'
      }
    end

    it 'passes validation with type and service' do
      @dummy_class.params = { type: 'type', services: 'service' }
      expect(@dummy_class.validate_no_services_without_type).to be_nil
    end
  end

  describe 'type and services validation' do
    it 'passes validation when type and services are known' do
      @dummy_class.params = { type: 'benefits', services: ['BurialClaimAssistance'] }
      expect(@dummy_class.validate_type_and_services_known).to be_nil
    end

    it 'raises an exception for unknown type and known service' do
      @dummy_class.params = { type: 'blah', services: ['BurialClaimAssistance'] }
      expect do
        @dummy_class.validate_type_and_services_known
      end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
        expect(error.message).to eq 'Invalid field value'
      }
    end

    it 'raises an exception for known type and unknown service' do
      @dummy_class.params = { type: 'benefits', services: ['blah'] }
      expect do
        @dummy_class.validate_type_and_services_known
      end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
        expect(error.message).to eq 'Invalid field value'
      }
    end

    it 'raises an exception for mismatched type and service' do
      @dummy_class.params = { type: 'benefits', services: ['MentalHealthCare'] }
      expect do
        @dummy_class.validate_type_and_services_known
      end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
        expect(error.message).to eq 'Invalid field value'
      }
    end
  end

  describe 'street address validation' do
    it 'raises an exception when street address has only letters and no digits' do
      @dummy_class.params = { street_address: 'main st' }
      expect do
        @dummy_class.validate_street_address
      end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
        expect(error.message).to eq 'Invalid field value'
      }
    end

    it 'validates with just numbers' do
      @dummy_class.params = { street_address: '1234' }
      expect(@dummy_class.validate_street_address).to be_nil
    end

    it 'validates with numbers and letters' do
      @dummy_class.params = { street_address: '1234 Main st' }
      expect(@dummy_class.validate_street_address).to be_nil
    end

    it 'does not run validation when street address is missing' do
      @dummy_class.params = {}
      expect(@dummy_class.validate_street_address).to be_nil
    end
  end

  describe 'drive time validation' do
    it 'does not run validation when drive time is missing' do
      @dummy_class.params = {}
      expect(@dummy_class.validate_drive_time).to be_nil
    end

    it 'passes validation when integer' do
      @dummy_class.params = { drive_time: 50 }
      expect(@dummy_class.validate_drive_time).to eq(50)
    end

    it 'passes validation when float' do
      @dummy_class.params = { drive_time: 50.5 }
      expect(@dummy_class.validate_drive_time).to eq(50)
    end

    it 'fails validation when not number' do
      @dummy_class.params = { drive_time: 'fifty' }
      expect do
        @dummy_class.validate_drive_time
      end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
        expect(error.message).to eq 'Invalid field value'
      }
    end
  end

  describe 'lat validation' do
    it 'does not run validation when lat is missing' do
      @dummy_class.params = {}
      expect(@dummy_class.validate_lat).to be_nil
    end

    it 'passes validation when integer' do
      @dummy_class.params = { lat: 50 }
      expect(@dummy_class.validate_lat).to eq(50.0)
    end

    it 'passes validation when float' do
      @dummy_class.params = { lat: 50.5 }
      expect(@dummy_class.validate_lat).to eq(50.5)
    end

    it 'fails validation when not number' do
      @dummy_class.params = { lat: 'fifty' }
      expect do
        @dummy_class.validate_lat
      end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
        expect(error.message).to eq 'Invalid field value'
      }
    end
  end

  describe 'lng validation' do
    it 'does not run validation when lng is missing' do
      @dummy_class.params = {}
      expect(@dummy_class.validate_lng).to be_nil
    end

    it 'passes validation when integer' do
      @dummy_class.params = { lng: 50 }
      expect(@dummy_class.validate_lng).to eq(50.0)
    end

    it 'passes validation when float' do
      @dummy_class.params = { lng: 50.5 }
      expect(@dummy_class.validate_lng).to eq(50.5)
    end

    it 'fails validation when not number' do
      @dummy_class.params = { lng: 'fifty' }
      expect do
        @dummy_class.validate_lng
      end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
        expect(error.message).to eq 'Invalid field value'
      }
    end
  end

  describe 'bbox validation' do
    it 'does not run validation when bbox is missing' do
      @dummy_class.params = {}
      expect(@dummy_class.validate_bbox).to be_nil
    end

    it 'passes validation when integer' do
      @dummy_class.params = { bbox: %w[40 50 50 100] }
      expect(@dummy_class.validate_bbox).to eq(%w[40 50 50 100])
    end

    it 'passes validation when float' do
      @dummy_class.params = { bbox: %w[40.5 50.823 50.234 100.1324] }
      expect(@dummy_class.validate_bbox).to eq(%w[40.5 50.823 50.234 100.1324])
    end

    it 'fails validation when not number' do
      @dummy_class.params = { bbox: %w[40.5 fifty 50.234 100.1324] }
      expect do
        @dummy_class.validate_bbox
      end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
        expect(error.message).to eq 'Invalid field value'
      }
    end

    it 'fails validation when too many' do
      @dummy_class.params = { bbox: %w[40.5 50.234 50.234 100.1324 1234.23] }
      expect do
        @dummy_class.validate_bbox
      end.to raise_error(Common::Exceptions::InvalidFieldValue) { |error|
        expect(error.message).to eq 'Invalid field value'
      }
    end
  end

  describe 'a param exists from list validation' do
    REQUIRE_ONE_PARAM = %i[bbox long lat zip ids state].freeze

    it 'passes validation when lat and lng are present' do
      @dummy_class.params = { lat: 40.5, long: 50.2 }
      expect(@dummy_class.validate_a_param_exists(REQUIRE_ONE_PARAM)).to be_nil
    end

    it 'fails validation when lat is present without long' do
      @dummy_class.params = { lat: 40.5 }
      expect do
        @dummy_class.validate_a_param_exists(REQUIRE_ONE_PARAM)
      end.to raise_error(Common::Exceptions::ParameterMissing) { |error|
        expect(error.message).to eq 'Missing parameter'
      }
    end

    it 'fails validation when long is present without lat' do
      @dummy_class.params = { long: 40.5 }
      expect do
        @dummy_class.validate_a_param_exists(REQUIRE_ONE_PARAM)
      end.to raise_error(Common::Exceptions::ParameterMissing) { |error|
        expect(error.message).to eq 'Missing parameter'
      }
    end

    it 'passes validation when lat and state are present' do
      @dummy_class.params = { lat: 40.5, state: 'TX' }
      expect(@dummy_class.validate_a_param_exists(REQUIRE_ONE_PARAM)).to be_nil
    end

    it 'passes validation when zip is present' do
      @dummy_class.params = { zip: '75075' }
      expect(@dummy_class.validate_a_param_exists(REQUIRE_ONE_PARAM)).to be_nil
    end

    it 'passes validation when state is present' do
      @dummy_class.params = { state: 'TX' }
      expect(@dummy_class.validate_a_param_exists(REQUIRE_ONE_PARAM)).to be_nil
    end

    it 'passes validation when bbox is present' do
      @dummy_class.params = { bbox: %w[40.5 50.234 50.234 100.1324] }
      expect(@dummy_class.validate_a_param_exists(REQUIRE_ONE_PARAM)).to be_nil
    end

    it 'passes validation when ids are present' do
      @dummy_class.params = { ids: %w[1 2] }
      expect(@dummy_class.validate_a_param_exists(REQUIRE_ONE_PARAM)).to be_nil
    end

    it 'passes validation when all are present' do
      @dummy_class.params = {
        bbox: %w[40.5 50.234 50.234 100.1324], long: '45.5', lat: '30.5', zip: '75075', ids: %w[1 2], state: 'TX'
      }
      expect(@dummy_class.validate_a_param_exists(REQUIRE_ONE_PARAM)).to be_nil
    end

    it 'fails validation when params are empty' do
      @dummy_class.params = {}
      expect do
        @dummy_class.validate_a_param_exists(REQUIRE_ONE_PARAM)
      end.to raise_error(Common::Exceptions::ParameterMissing) { |error|
        expect(error.message).to eq 'Missing parameter'
      }
    end

    it 'fails validation when required params are not present' do
      @dummy_class.params = { type: 'type' }
      expect do
        @dummy_class.validate_a_param_exists(REQUIRE_ONE_PARAM)
      end.to raise_error(Common::Exceptions::ParameterMissing) { |error|
        expect(error.message).to eq 'Missing parameter'
      }
    end
  end

  describe 'location query validation' do
    it 'passes validation when no location query params are found' do
      @dummy_class.params = { type: 'type' }
      expect(@dummy_class.valid_location_query?).to be_truthy
    end

    it 'passes validation when lat and lng are present' do
      @dummy_class.params = { lat: 40.5, long: 40.2 }
      expect(@dummy_class.valid_location_query?).to be_truthy
    end

    it 'fails when only lat and not long is present' do
      @dummy_class.params = { lat: 40.5 }
      expected_hash = { json: { errors: [
        'You may only use ONE of these distance query parameter sets: lat/long, zip, state, or bbox'
      ] } }
      expect(@dummy_class.valid_location_query?)
        .to include(expected_hash)
    end

    it 'fails when only lat and not long is present' do
      @dummy_class.params = { long: 40.5 }
      expected_hash = { json: { errors: [
        'You may only use ONE of these distance query parameter sets: lat/long, zip, state, or bbox'
      ] } }
      expect(@dummy_class.valid_location_query?)
        .to include(expected_hash)
    end

    it 'passes validation when state is present' do
      @dummy_class.params = { state: 'TX' }
      expect(@dummy_class.valid_location_query?).to be_truthy
    end

    it 'passes validation when zip is present' do
      @dummy_class.params = { zip: '75075' }
      expect(@dummy_class.valid_location_query?).to be_truthy
    end

    it 'passes validation when bbox is present' do
      @dummy_class.params = { bbox: %w[40.5 50.234 50.234 100.1324] }
      expect(@dummy_class.valid_location_query?).to be_truthy
    end

    it 'passes validation when location query is with a non location query param' do
      @dummy_class.params = { bbox: %w[40.5 50.234 50.234 100.1324], type: 'type' }
      expect(@dummy_class.valid_location_query?).to be_truthy
    end

    it 'fails validation when multiple location query params are present' do
      @dummy_class.params = { bbox: %w[40.5 50.234 50.234 100.1324], state: 'tx' }
      expected_hash = { json: { errors: [
        'You may only use ONE of these distance query parameter sets: lat/long, zip, state, or bbox'
      ] } }
      expect(@dummy_class.valid_location_query?)
        .to include(expected_hash)
    end

    it 'fails validation when passing in all location queries' do
      @dummy_class.params = {
        bbox: %w[40.5 50.234 50.234 100.1324], long: '45.5', lat: '30.5', zip: '75075', state: 'TX'
      }
      expected_hash = { json: { errors: [
        'You may only use ONE of these distance query parameter sets: lat/long, zip, state, or bbox'
      ] } }
      expect(@dummy_class.valid_location_query?)
        .to include(expected_hash)
    end
  end

  describe 'nearby parameters validation' do
    REQUIRED_PARAMS = {
      address: %i[street_address city state zip].freeze,
      lat_lng: %i[lat lng].freeze
    }.freeze

    it 'passes validation for address params' do
      @dummy_class.params = { street_address: '123 main', city: 'plano', state: 'tx', zip: '75075' }
      expect(@dummy_class.validate_required_nearby_params(REQUIRED_PARAMS)).to be_nil
    end

    it 'passes validation for lat/lng params' do
      @dummy_class.params = { lat: '45.3', lng: '43.3' }
      expect(@dummy_class.validate_required_nearby_params(REQUIRED_PARAMS)).to be_nil
    end

    it 'passes validation for a valid required params set(lat/lng)' do
      @dummy_class.params = { street_address: '123 main', city: 'plano', state: 'tx', lat: '45.3', lng: '43.3' }
      expect(@dummy_class.validate_required_nearby_params(REQUIRED_PARAMS)).to be_nil
    end

    it 'passes validation for a valid required params set(address)' do
      @dummy_class.params = { street_address: '123 main', city: 'plano', state: 'tx', zip: '75075', lat: '45.3' }
      expect(@dummy_class.validate_required_nearby_params(REQUIRED_PARAMS)).to be_nil
    end

    it 'fails validation when ambiguous' do
      @dummy_class.params = {
        lat: '45.3', lng: '43.3', street_address: '123 main', city: 'plano', state: 'tx', zip: '75075'
      }
      expect do
        @dummy_class.validate_required_nearby_params(REQUIRED_PARAMS)
      end.to raise_error(Common::Exceptions::ParameterMissing) { |error|
        expect(error.message).to eq 'Missing parameter'
      }
    end

    it 'fails validation when missing address params' do
      @dummy_class.params = {
        street_address: '123 main', state: 'tx', zip: '75075'
      }
      expect do
        @dummy_class.validate_required_nearby_params(REQUIRED_PARAMS)
      end.to raise_error(Common::Exceptions::ParameterMissing) { |error|
        expect(error.message).to eq 'Missing parameter'
      }
    end

    it 'fails validation when missing lat/lng params' do
      @dummy_class.params = {
        lat: '43.3'
      }
      expect do
        @dummy_class.validate_required_nearby_params(REQUIRED_PARAMS)
      end.to raise_error(Common::Exceptions::ParameterMissing) { |error|
        expect(error.message).to eq 'Missing parameter'
      }
    end
  end
end
