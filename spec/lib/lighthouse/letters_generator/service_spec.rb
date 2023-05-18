# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/letters_generator/service'
require 'lighthouse/letters_generator/service_error'

FAKE_RESPONSES_PATH = 'spec/lib/lighthouse/letters_generator/fakeResponses'

RSpec.describe Lighthouse::LettersGenerator::Service do
  before do
    @stubs = Faraday::Adapter::Test::Stubs.new
    conn = Faraday.new { |b| b.adapter(:test, @stubs) }
    allow_any_instance_of(Lighthouse::LettersGenerator::Configuration).to receive(:connection).and_return(conn)
  end

  describe '#get_eligible_letter_types' do
    it 'returns a list of eligible letter types' do
      # Arrange
      fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeResponse.json")
      fake_response_body = JSON.parse(fake_response_json)

      @stubs.get('/eligible-letters?icn=DOLLYPARTON') do
        [200, {}, fake_response_body]
      end

      client = Lighthouse::LettersGenerator::Service.new

      # Act
      response = client.get_eligible_letter_types('DOLLYPARTON')

      # Assert
      expect(response[:letters][0]).to have_key(:letterType)
      expect(response[:letters][0]).to have_key(:name)
      expect(response).to have_key(:letter_destination)
    end

    context 'Error handling' do
      it 'handles an error that returns a detailed response' do
        ## This test covers classes of client errors in lighthouse that
        ## have a detailed response, exemplified in fakeBadRequest.json.
        ## Status codes include: 400, 404, 406, 433, 500
        ## Link: https://developer.va.gov/explore/verification/docs/va_letter_generator

        fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeBadRequest.json")
        fake_response_body = JSON.parse(fake_response_json)
        @stubs.get('/eligible-letters?icn=BADREQUEST') do
          raise Faraday::BadRequestError.new('YIKES', { body: fake_response_body })
        end

        client = Lighthouse::LettersGenerator::Service.new

        expect { client.get_eligible_letter_types('BADREQUEST') }.to raise_error do |error|
          expect(error).to be_an_instance_of(Lighthouse::LettersGenerator::ServiceError)
          expect(error.errors.first.status).to eq(fake_response_body['status'].to_s)
          expect(error.errors.first.meta[:message]).to eq(fake_response_body['detail'])
        end
      end

      it 'handles an error that returns a simplified response' do
        ## This test covers classes of client errors in lighthouse that
        ## have a detailed response, exemplified in fakeBadRequest.json.
        ## Status codes include: 401, 403, 413, 429
        ## Link: https://developer.va.gov/explore/verification/docs/va_letter_generator

        fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeUnauthorized.json")
        fake_response_body = JSON.parse(fake_response_json)
        @stubs.get('/eligible-letters?icn=BadActor') do
          raise Faraday::UnauthorizedError.new("don't go in there", { body: fake_response_body })
        end

        client = Lighthouse::LettersGenerator::Service.new

        expect { client.get_eligible_letter_types('BadActor') }.to raise_error do |error|
          expect(error).to be_an_instance_of(Lighthouse::LettersGenerator::ServiceError)
        end
      end
    end
  end

  describe '#get_benefit_information' do
    it 'returns a list of benefit information' do
      # Arrange
      fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeResponse.json")
      fake_response_body = JSON.parse(fake_response_json)

      @stubs.get('/eligible-letters?icn=DOLLYPARTON') do
        [200, {}, fake_response_body]
      end

      client = Lighthouse::LettersGenerator::Service.new

      # Act
      response = client.get_benefit_information('DOLLYPARTON')

      # Assert
      expect(response).to have_key(:benefitInformation)
      expect(response[:benefitInformation]).not_to be_nil
    end

    context 'Transformation' do
      it 'performs transformation on benefit info' do
        fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeResponse.json")
        fake_response_body = JSON.parse(fake_response_json)

        @stubs.get('/eligible-letters?icn=DOLLYPARTON') do
          [200, {}, fake_response_body]
        end

        client = Lighthouse::LettersGenerator::Service.new
        response = client.get_benefit_information('DOLLYPARTON')

        expect(response).to have_key(:benefitInformation)
        expect(response[:benefitInformation]).not_to be_nil
        # Ensures the tranform works
        expect(response[:benefitInformation]).to have_key(:awardEffectiveDate)
        # Ensures the non-transformable data is present
        expect(response[:benefitInformation]).to have_key(:serviceConnectedPercentage)
        # Ensure (has)chapter35EligibilityDateTime is not present
        expect(response[:benefitInformation]).not_to have_key(:chapter35EligibilityDateTime)
        # Ensure enteredDateTime has been transformed to enteredDate
        expect(response[:militaryService][0]).to have_key(:enteredDate)
        expect(response[:militaryService][0]).not_to have_key(:enteredDateTime)
        # Ensure releasedDateTime has been transformed to releasedDate
        expect(response[:militaryService][0]).to have_key(:releasedDate)
        expect(response[:militaryService][0]).not_to have_key(:releasedDateTime)
      end
    end
  end

  describe '#download_letter' do
    it 'returns a letter pdf without letter options' do
      # Arrange
      fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeResponse.json")
      fake_response_body = JSON.parse(fake_response_json)

      @stubs.get('/letters/BENEFIT_SUMMARY/letter?icn=DOLLYPARTON') do
        [200, {}, fake_response_body]
      end

      # Act
      client = Lighthouse::LettersGenerator::Service.new
      response = client.download_letter('DOLLYPARTON', 'BENEFIT_SUMMARY')

      # Assert
      @stubs.verify_stubbed_calls
      expect(response).not_to be_nil
    end

    it 'returns a letter pdf with letter options' do
      # Arrange
      fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeResponse.json")
      fake_response_body = JSON.parse(fake_response_json)
      download_path = '/letters/BENEFIT_SUMMARY/letter'
      query_params = 'icn=DOLLYPARTON?serviceConnectedDisabilities=true&chapter35Eligibility=true'

      @stubs.get("#{download_path}?#{query_params}") do
        [200, {}, fake_response_body]
      end

      letter_options = fake_response_body['benefitInformation']

      # Act
      client = Lighthouse::LettersGenerator::Service.new
      response = client.download_letter('DOLLYPARTON', 'BENEFIT_SUMMARY', letter_options)

      # Assert
      @stubs.verify_stubbed_calls
      expect(response).not_to be_nil
    end

    context 'error handling' do
      it 'returns a 400 if the letter type is not valid' do
        # Arrange
        fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeResponse.json")
        fake_response_body = JSON.parse(fake_response_json)

        @stubs.get('/letters/LETTER_TO_GRANDMA/letter?icn=DOLLYPARTON') do
          [200, {}, fake_response_body]
        end

        client = Lighthouse::LettersGenerator::Service.new

        # Assert
        expect { client.download_letter('DOLLYPARTON', 'LETTER_TO_GRANDMA') }.to raise_error do |error|
          expect(error).to be_an_instance_of(Lighthouse::LettersGenerator::ServiceError)
          expect(error.status).to eq(400)
        end
      end

      it 'handles an error returned from Lighthouse' do
        fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeBadRequest.json")
        fake_response_body = JSON.parse(fake_response_json)
        @stubs.get('/letters/BENEFITS_SUMMARY/letter?icn=BADREQUEST') do
          raise Faraday::BadRequestError.new('YIKES', fake_response_body)
        end

        client = Lighthouse::LettersGenerator::Service.new

        expect { client.download_letter('BADREQUEST', 'BENEFITS_SUMMARY') }.to raise_error do |error|
          expect(error).to be_an_instance_of(Lighthouse::LettersGenerator::ServiceError)
        end
      end
    end
  end
end
