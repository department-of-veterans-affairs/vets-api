# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AddressValidationService do
  let(:service) { described_class.new }
  let(:mock_validation_service) { instance_double(VAProfile::AddressValidation::V3::Service) }
  let(:service_with_mock) { described_class.new(validation_service: mock_validation_service) }

  let(:valid_address_hash) do
    {
      'address_line1' => '123 Main St',
      'address_line2' => 'Suite 100',
      'address_line3' => 'Building A',
      'city' => 'Brooklyn',
      'state_code' => 'NY',
      'zip_code' => '11249'
    }
  end

  let(:valid_api_response) do
    {
      'candidate_addresses' => [
        {
          'address_type' => 'Domestic',
          'address_line1' => '123 Main St',
          'address_line2' => 'Suite 100',
          'address_line3' => 'Building A',
          'city_name' => 'Brooklyn',
          'state' => {
            'state_name' => 'New York',
            'state_code' => 'NY'
          },
          'zip_code5' => '11249',
          'zip_code4' => '3939',
          'country' => {
            'country_name' => 'United States',
            'iso3_code' => 'USA'
          },
          'county' => {
            'county_name' => 'Kings',
            'county_code' => '36047'
          },
          'geocode' => {
            'latitude' => 40.717029,
            'longitude' => -73.964956
          }
        }
      ]
    }
  end

  let(:zero_coordinate_response) do
    {
      'candidate_addresses' => [
        {
          'address_type' => 'Domestic',
          'address_line1' => 'PO Box 123',
          'city_name' => 'Brooklyn',
          'state' => {
            'state_name' => 'New York',
            'state_code' => 'NY'
          },
          'zip_code5' => '11249',
          'zip_code4' => '3939',
          'country' => {
            'country_name' => 'United States',
            'iso3_code' => 'USA'
          },
          'county' => {
            'county_name' => 'Kings',
            'county_code' => '36047'
          },
          'geocode' => {
            'latitude' => 0,
            'longitude' => 0
          }
        }
      ]
    }
  end

  let(:invalid_api_response) do
    { 'candidate_addresses' => [] }
  end

  describe '#validate_address' do
    context 'with a valid address' do
      before do
        allow(mock_validation_service).to receive(:candidate).and_return(valid_api_response)
      end

      it 'returns validated address attributes' do
        result = service_with_mock.validate_address(valid_address_hash)

        expect(result).to be_a(Hash)
        expect(result[:address_line1]).to eq('123 Main St')
        expect(result[:city]).to eq('Brooklyn')
        expect(result[:state_code]).to eq('NY')
        expect(result[:lat]).to eq(40.717029)
        expect(result[:long]).to eq(-73.964956)
        expect(result[:location]).to eq('POINT(-73.964956 40.717029)')
      end

      it 'includes all expected attributes' do
        result = service_with_mock.validate_address(valid_address_hash)

        expect(result.keys).to include(
          :address_type, :address_line1, :address_line2, :address_line3,
          :city, :province, :state_code, :zip_code, :zip_suffix,
          :country_code_iso3, :country_name, :county_name, :county_code,
          :lat, :long, :location
        )
      end
    end

    context 'with a blank address' do
      it 'handles nil address' do
        expect(service.validate_address(nil)).to be_nil
      end

      it 'returns nil when given empty hash' do
        expect(service.validate_address({})).to be_nil
      end
    end

    context 'when validation fails' do
      before do
        allow(mock_validation_service).to receive(:candidate).and_return(invalid_api_response)
      end

      it 'returns nil for failed validation' do
        result = service_with_mock.validate_address(valid_address_hash)
        expect(result).to be_nil
      end
    end

    context 'when API raises BackendServiceException' do
      before do
        allow(mock_validation_service).to receive(:candidate)
          .and_raise(Common::Exceptions::BackendServiceException.new('API error'))
      end

      it 'logs the error and returns nil' do
        expect(Rails.logger).to receive(:error).with(/VAProfile address validation API error/)
        result = service_with_mock.validate_address(valid_address_hash)
        expect(result).to be_nil
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow(mock_validation_service).to receive(:candidate).and_raise(StandardError.new('Unexpected error'))
      end

      it 'catches and logs the error' do
        expect(Rails.logger).to receive(:error).with(/Address validation error/)
        result = service_with_mock.validate_address(valid_address_hash)
        expect(result).to be_nil
      end
    end

    context 'when initial validation raises ADDRVAL108 but retry succeeds' do
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

      it 'returns validated attributes after retrying' do
        expect(mock_validation_service).to receive(:candidate).ordered.and_raise(candidate_not_found_exception)
        expect(mock_validation_service).to receive(:candidate).ordered.and_return(valid_api_response)

        result = service_with_mock.validate_address(valid_address_hash)
        expect(result).to be_a(Hash)
        expect(result[:address_line1]).to eq('123 Main St')
        expect(result[:city]).to eq('Brooklyn')
      end
    end
  end

  describe '#build_validation_address' do
    it 'creates a VAProfile ValidationAddress object' do
      result = service.build_validation_address(valid_address_hash)

      expect(result).to be_a(VAProfile::Models::ValidationAddress)
      expect(result.address_line1).to eq('123 Main St')
      expect(result.city).to eq('Brooklyn')
      expect(result.state_code).to eq('NY')
      expect(result.zip_code).to eq('11249')
      expect(result.address_pou).to eq('RESIDENCE')
    end

    it 'handles missing optional fields' do
      minimal_address = {
        'address_line1' => '123 Main St',
        'city' => 'Brooklyn',
        'state_code' => 'NY',
        'zip_code' => '11249'
      }

      result = service.build_validation_address(minimal_address)

      expect(result).to be_a(VAProfile::Models::ValidationAddress)
      expect(result.address_line2).to be_nil
      expect(result.address_line3).to be_nil
    end

    context 'when RepresentationManagement::AddressPreprocessor is available' do
      it 'uses the cleaned address values from the preprocessor' do
        cleaned_address = valid_address_hash.merge(
          'address_line1' => 'PO Box 123',
          'address_line2' => nil
        )

        allow(RepresentationManagement::AddressPreprocessor)
          .to receive(:clean)
          .with(valid_address_hash)
          .and_return(cleaned_address)

        result = service.build_validation_address(valid_address_hash)

        expect(RepresentationManagement::AddressPreprocessor).to have_received(:clean).with(valid_address_hash)
        expect(result).to be_a(VAProfile::Models::ValidationAddress)
        expect(result.address_line1).to eq('PO Box 123')
        expect(result.address_line2).to be_nil
        expect(result.city).to eq('Brooklyn')
        expect(result.state_code).to eq('NY')
        expect(result.zip_code).to eq('11249')
      end
    end
  end

  describe '#call_validation_api' do
    let(:validation_address) { service.build_validation_address(valid_address_hash) }

    before do
      allow(mock_validation_service).to receive(:candidate).and_return(valid_api_response)
    end

    it 'calls the VAProfile service with the validation address' do
      expect(mock_validation_service).to receive(:candidate).with(validation_address)
      service_with_mock.call_validation_api(validation_address)
    end

    it 'returns the API response' do
      result = service_with_mock.call_validation_api(validation_address)
      expect(result).to eq(valid_api_response)
    end
  end

  describe '#get_best_address_candidate' do
    context 'with a valid address returning non-zero coordinates' do
      before do
        allow(mock_validation_service).to receive(:candidate).and_return(valid_api_response)
      end

      it 'uses the original response' do
        result = service_with_mock.get_best_address_candidate(valid_address_hash)
        expect(result).to eq(valid_api_response)
      end

      it 'skips retry logic' do
        expect(mock_validation_service).to receive(:candidate).once
        service_with_mock.get_best_address_candidate(valid_address_hash)
      end
    end

    context 'with zero coordinates that succeed on retry' do
      let(:retry_success_response) do
        response = valid_api_response.deep_dup
        response['candidate_addresses'][0]['address_line1'] = '123 Main St (Retry 1)'
        response
      end

      before do
        allow(mock_validation_service).to receive(:candidate)
          .and_return(zero_coordinate_response, retry_success_response)
      end

      it 'uses the retried response instead' do
        result = service_with_mock.get_best_address_candidate(valid_address_hash)
        expect(result['candidate_addresses'][0]['address_line1']).to eq('123 Main St (Retry 1)')
      end

      it 'makes a retry attempt' do
        expect(mock_validation_service).to receive(:candidate).twice
        service_with_mock.get_best_address_candidate(valid_address_hash)
      end
    end

    context 'with zero coordinates that fail all retries' do
      before do
        allow(mock_validation_service).to receive(:candidate).and_return(zero_coordinate_response)
      end

      it 'gives up and returns nil' do
        result = service_with_mock.get_best_address_candidate(valid_address_hash)
        expect(result).to be_nil
      end

      it 'tries all retry attempts' do
        # Original + 3 retries = 4 total calls
        expect(mock_validation_service).to receive(:candidate).exactly(4).times
        service_with_mock.get_best_address_candidate(valid_address_hash)
      end
    end

    context 'with invalid address' do
      before do
        allow(mock_validation_service).to receive(:candidate).and_return(invalid_api_response)
      end

      it 'returns nil when address cannot be validated' do
        result = service_with_mock.get_best_address_candidate(valid_address_hash)
        expect(result).to be_nil
      end
    end

    context 'when initial validation raises CandidateAddressNotFound (ADDRVAL108) and retry succeeds' do
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

      it 'retries after ADDRVAL108 and returns the retry response' do
        expect(mock_validation_service).to receive(:candidate).ordered.and_raise(candidate_not_found_exception)
        expect(mock_validation_service).to receive(:candidate).ordered.and_return(valid_api_response)
        result = service_with_mock.get_best_address_candidate(valid_address_hash)
        expect(result).to eq(valid_api_response)
      end
    end

    context 'when initial validation raises ADDRVAL108 and all retries still fail' do
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

      it 'returns nil when no valid candidate can be found after ADDRVAL108 retries' do
        expect(mock_validation_service).to receive(:candidate).ordered.and_raise(candidate_not_found_exception)
        3.times do
          expect(mock_validation_service).to receive(:candidate).ordered.and_return(zero_coordinate_response)
        end

        result = service_with_mock.get_best_address_candidate(valid_address_hash)
        expect(result).to be_nil
      end
    end
  end

  describe '#retry_validation' do
    let(:po_box_address) do
      {
        'address_line1' => '123 Main St',
        'address_line2' => 'PO Box 456',
        'address_line3' => 'Suite 789',
        'city' => 'Brooklyn',
        'state_code' => 'NY',
        'zip_code' => '11249'
      }
    end

    context 'when address_line1 succeeds' do
      before do
        allow(mock_validation_service).to receive(:candidate).and_return(valid_api_response)
      end

      it 'succeeds on first retry attempt' do
        result = service_with_mock.retry_validation(po_box_address)
        expect(result).to eq(valid_api_response)
      end

      it 'stops after one API call' do
        expect(mock_validation_service).to receive(:candidate).once
        service_with_mock.retry_validation(po_box_address)
      end
    end

    context 'when a retry attempt raises BackendServiceException' do
      let(:po_box_address) do
        {
          'address_line1' => '123 Main St',
          'address_line2' => 'PO Box 456',
          'address_line3' => 'Suite 789',
          'city' => 'Brooklyn',
          'state_code' => 'NY',
          'zip_code' => '11249'
        }
      end

      let(:backend_error) do
        Common::Exceptions::BackendServiceException.new(
          'VET360_AV_ERROR',
          { detail: { 'messages' => [{ 'code' => 'ADDRVAL999', 'text' => 'Some backend error' }] } },
          500,
          nil
        )
      end

      before do
        allow(service_with_mock).to receive(:modified_validation) do |_address_hash, attempt_number|
          raise backend_error if attempt_number == 1

          valid_api_response
        end
      end

      it 'logs the error and continues to subsequent retry attempts' do
        expect(Rails.logger).to receive(:error).with(
          a_string_matching(/Address validation retry attempt 1[\s\S]*failed:/)
        )
        result = service_with_mock.retry_validation(po_box_address)

        # We should have tried again after the exception
        expect(service_with_mock).to have_received(:modified_validation).with(po_box_address, 1).once
        # And ultimately return the successful response
        expect(service_with_mock).to have_received(:modified_validation).with(po_box_address, 2).once
        expect(result).to eq(valid_api_response)
      end
    end

    context 'when address_line2 succeeds on second retry' do
      let(:retry_2_response) do
        response = valid_api_response.deep_dup
        response['candidate_addresses'][0]['address_line1'] = 'PO Box 456'
        response
      end

      before do
        allow(mock_validation_service).to receive(:candidate)
          .and_return(zero_coordinate_response, retry_2_response)
      end

      it 'works on the second try' do
        result = service_with_mock.retry_validation(po_box_address)
        expect(result['candidate_addresses'][0]['address_line1']).to eq('PO Box 456')
      end

      it 'makes two API calls' do
        expect(mock_validation_service).to receive(:candidate).twice
        service_with_mock.retry_validation(po_box_address)
      end
    end

    context 'when address_line3 succeeds on third retry' do
      let(:retry_3_response) do
        response = valid_api_response.deep_dup
        response['candidate_addresses'][0]['address_line1'] = 'Suite 789'
        response
      end

      before do
        allow(mock_validation_service).to receive(:candidate)
          .and_return(zero_coordinate_response, zero_coordinate_response, retry_3_response)
      end

      it 'eventually succeeds on third attempt' do
        result = service_with_mock.retry_validation(po_box_address)
        expect(result['candidate_addresses'][0]['address_line1']).to eq('Suite 789')
      end

      it 'tries three times before succeeding' do
        expect(mock_validation_service).to receive(:candidate).exactly(3).times
        service_with_mock.retry_validation(po_box_address)
      end
    end

    context 'when all retries fail' do
      before do
        allow(mock_validation_service).to receive(:candidate).and_return(zero_coordinate_response)
      end

      it 'gives up and returns last response' do
        result = service_with_mock.retry_validation(po_box_address)
        expect(result).to eq(zero_coordinate_response)
      end

      it 'exhausts all three retry attempts' do
        expect(mock_validation_service).to receive(:candidate).exactly(3).times
        service_with_mock.retry_validation(po_box_address)
      end
    end

    context 'when address has no line1' do
      let(:no_line1_address) do
        {
          'address_line2' => 'PO Box 456',
          'address_line3' => 'Suite 789',
          'city' => 'Brooklyn',
          'state_code' => 'NY',
          'zip_code' => '11249'
        }
      end

      before do
        allow(mock_validation_service).to receive(:candidate).and_return(valid_api_response)
      end

      it 'jumps to line2 when line1 is missing' do
        expect(mock_validation_service).to receive(:candidate).once
        service_with_mock.retry_validation(no_line1_address)
      end
    end

    context 'when address has only line1' do
      let(:only_line1_address) do
        {
          'address_line1' => '123 Main St',
          'city' => 'Brooklyn',
          'state_code' => 'NY',
          'zip_code' => '11249'
        }
      end

      before do
        allow(mock_validation_service).to receive(:candidate).and_return(zero_coordinate_response)
      end

      it 'stops after trying line1' do
        expect(mock_validation_service).to receive(:candidate).once
        service_with_mock.retry_validation(only_line1_address)
      end
    end
  end

  describe '#build_address_attributes' do
    context 'with valid API response' do
      it 'returns complete address attributes' do
        result = service.build_address_attributes(valid_api_response)

        expect(result[:address_type]).to eq('Domestic')
        expect(result[:address_line1]).to eq('123 Main St')
        expect(result[:city]).to eq('Brooklyn')
        expect(result[:state_code]).to eq('NY')
        expect(result[:zip_code]).to eq('11249')
        expect(result[:zip_suffix]).to eq('3939')
        expect(result[:country_code_iso3]).to eq('USA')
        expect(result[:country_name]).to eq('United States')
        expect(result[:county_name]).to eq('Kings')
        expect(result[:county_code]).to eq('36047')
        expect(result[:lat]).to eq(40.717029)
        expect(result[:long]).to eq(-73.964956)
        expect(result[:location]).to eq('POINT(-73.964956 40.717029)')
      end
    end

    context 'with blank response' do
      it 'handles nil response' do
        expect(service.build_address_attributes(nil)).to eq({})
      end

      it 'returns empty hash when given empty hash' do
        expect(service.build_address_attributes({})).to eq({})
      end

      it 'handles missing candidate_addresses gracefully' do
        expect(service.build_address_attributes({ 'other_key' => 'value' })).to eq({})
      end

      it 'returns empty hash when candidates array is empty' do
        expect(service.build_address_attributes({ 'candidate_addresses' => [] })).to eq({})
      end
    end
  end

  describe '#address_valid?' do
    it 'returns true when response is valid' do
      expect(service.address_valid?(valid_api_response)).to be true
    end

    it 'handles nil input' do
      expect(service.address_valid?(nil)).to be false
    end

    it 'rejects empty hash' do
      expect(service.address_valid?({})).to be false
    end

    it 'rejects response missing candidate_addresses key' do
      expect(service.address_valid?({ 'other_key' => 'value' })).to be false
    end

    it 'returns false when no candidates found' do
      expect(service.address_valid?({ 'candidate_addresses' => [] })).to be false
    end
  end

  describe '#lat_long_zero?' do
    it 'detects zero coordinates' do
      expect(service.lat_long_zero?(zero_coordinate_response)).to be true
    end

    it 'returns false when coords are valid' do
      expect(service.lat_long_zero?(valid_api_response)).to be false
    end

    it 'handles nil response' do
      expect(service.lat_long_zero?(nil)).to be false
    end

    it 'handles empty hash' do
      expect(service.lat_long_zero?({})).to be false
    end

    it 'returns false when candidates missing' do
      expect(service.lat_long_zero?({ 'other_key' => 'value' })).to be false
    end

    it 'handles missing geocode data' do
      response = { 'candidate_addresses' => [{ 'address_line1' => '123 Main St' }] }
      expect(service.lat_long_zero?(response)).to be false
    end
  end

  describe '#retriable?' do
    it 'considers nil retriable' do
      expect(service.retriable?(nil)).to be true
    end

    it 'marks invalid responses as retriable' do
      expect(service.retriable?(invalid_api_response)).to be true
    end

    it 'treats zero coords as retriable' do
      expect(service.retriable?(zero_coordinate_response)).to be true
    end

    it 'stops retrying for valid coords' do
      expect(service.retriable?(valid_api_response)).to be false
    end
  end

  describe 'integration with default validation service' do
    let(:service_with_defaults) { described_class.new }

    it 'instantiates VAProfile service automatically' do
      # This tests that the service can be instantiated without mocks
      expect { service_with_defaults }.not_to raise_error
    end
  end

  describe 'custom max_retries configuration' do
    let(:custom_service) { described_class.new(validation_service: mock_validation_service, max_retries: 2) }

    it 'allows configurable retry limit' do
      expect { custom_service }.not_to raise_error
    end
  end
end
