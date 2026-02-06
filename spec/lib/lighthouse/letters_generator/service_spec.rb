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

  context 'type validation' do
    it 'returns true if the type is present in the allow list' do
      service = Lighthouse::LettersGenerator::Service.new

      is_valid = service.valid_type?('BENEFIT_summary')
      expect(is_valid).to be(true)
    end

    it 'returns false if the type is not present in the allow list' do
      service = Lighthouse::LettersGenerator::Service.new

      is_valid = service.valid_type?('SUMMARY_of_BENEFITS')
      expect(is_valid).to be(false)
    end

    context 'when fmp_benefits_authorization_letter feature flag is enabled' do
      it 'returns true for foreign_medical_program letter type' do
        allow(Flipper).to receive(:enabled?).with(:fmp_benefits_authorization_letter).and_return(true)
        service = Lighthouse::LettersGenerator::Service.new

        is_valid = service.valid_type?('foreign_medical_program')
        expect(is_valid).to be(true)
      end
    end

    context 'when fmp_benefits_authorization_letter feature flag is disabled' do
      it 'returns false for foreign_medical_program letter type' do
        allow(Flipper).to receive(:enabled?).with(:fmp_benefits_authorization_letter).and_return(false)
        service = Lighthouse::LettersGenerator::Service.new

        is_valid = service.valid_type?('foreign_medical_program')
        expect(is_valid).to be(false)
      end
    end
  end

  context 'a request' do
    it 'always gets the lighthouse token via get_access_token' do
      expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
        .to receive(:get_access_token)
        .twice
        .and_return('faketoken')

      fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeResponse.json")
      fake_response_body = JSON.parse(fake_response_json)

      @stubs.get('/eligible-letters?icn=DOLLYPARTON') do
        [200, {}, fake_response_body]
      end

      client = Lighthouse::LettersGenerator::Service.new

      client.get_eligible_letter_types('DOLLYPARTON')
      client.get_eligible_letter_types('DOLLYPARTON')
    end

    it 'returns a 504 on timeout' do
      expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
        .to receive(:get_access_token)
        .and_return('faketoken')

      @stubs.get('/eligible-letters?icn=TIMEOUT_ICN') do
        raise Faraday::TimeoutError.new('waiting waiting', { status: 504 })
      end

      client = Lighthouse::LettersGenerator::Service.new

      expect { client.get_eligible_letter_types('TIMEOUT_ICN') }.to raise_error do |error|
        expect(error).to be_an_instance_of(Common::Exceptions::GatewayTimeout)
      end
    end
  end

  describe '#get_letter' do
    it 'returns a full json representation of a letter without letter options' do
      expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
        .to receive(:get_access_token)
        .once
        .and_return('faketoken')

      fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeProofOfServiceLetterResponse.json")
      fake_response_body = JSON.parse(fake_response_json)

      @stubs.get('/letter-contents/proof_of_service?icn=DOLLYPARTON') do
        [200, {}, fake_response_body]
      end

      client = Lighthouse::LettersGenerator::Service.new

      response = client.get_letter('DOLLYPARTON', 'proof_of_service')

      expect(response).to have_key('letterDescription')
      expect(response).to have_key('letterContent')
      expect(response['letterContent'].length).to eq(3)
      response['letterContent'].each do |content|
        expect(content.keys).to match_array(%w[contentKey contentTitle content])
      end
    end

    it 'returns a full json representation of a letter with options' do
      expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
        .to receive(:get_access_token)
        .once
        .and_return('faketoken')

      fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeProofOfServiceLetterResponse.json")
      fake_response_body = JSON.parse(fake_response_json)
      query_params = 'icn=DOLLYPARTON&serviceConnectedDisabilities=true'

      @stubs.get("/letter-contents/proof_of_service?#{query_params}") do
        [200, {}, fake_response_body]
      end

      client = Lighthouse::LettersGenerator::Service.new

      response = client.get_letter('DOLLYPARTON', 'proof_of_service', { serviceConnectedDisabilities: true })
      expect(response).to have_key('letterDescription')
      expect(response).to have_key('letterContent')
      expect(response['letterContent'].length).to eq(3)
      response['letterContent'].each do |content|
        expect(content.keys).to match_array(%w[contentKey contentTitle content])
      end
    end

    context 'Error handling' do
      it 'handles an error that returns a detailed response' do
        ## This test covers classes of client errors in lighthouse that
        ## have a detailed response, exemplified in fakeBadRequest.json.
        ## Status codes include: 400, 404, 406, 433, 500
        ## Link: https://developer.va.gov/explore/verification/docs/va_letter_generator

        expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
          .to receive(:get_access_token)
          .once
          .and_return('faketoken')

        fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeBadRequest.json")
        fake_response_body = JSON.parse(fake_response_json)
        @stubs.get('/letter-contents/proof_of_service?icn=BADREQUEST') do
          raise Faraday::BadRequestError.new('YIKES', { status: 400, body: fake_response_body })
        end

        client = Lighthouse::LettersGenerator::Service.new

        expect { client.get_letter('BADREQUEST', 'proof_of_service') }.to raise_error do |error|
          expect(error).to be_an_instance_of(Common::Exceptions::BadRequest)
        end
      end

      it 'handles an error that returns a simplified response' do
        ## This test covers classes of client errors in lighthouse that
        ## have a detailed response, exemplified in fakeBadRequest.json.
        ## Status codes include: 401, 403, 413, 429
        ## Link: https://developer.va.gov/explore/verification/docs/va_letter_generator

        expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
          .to receive(:get_access_token)
          .once
          .and_return('faketoken')

        fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeUnauthorized.json")
        fake_response_body = JSON.parse(fake_response_json)
        @stubs.get('/letter-contents/proof_of_service?icn=BadActor') do
          raise Faraday::UnauthorizedError.new("don't go in there", { status: 401, body: fake_response_body })
        end

        client = Lighthouse::LettersGenerator::Service.new

        expect { client.get_letter('BadActor', 'proof_of_service') }.to raise_error do |error|
          expect(error).to be_an_instance_of(Common::Exceptions::Unauthorized)
        end
      end
    end
  end

  describe '#get_eligible_letter_types' do
    it 'returns a list of eligible letter types' do
      expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
        .to receive(:get_access_token)
        .once
        .and_return('faketoken')

      fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeResponse.json")
      fake_response_body = JSON.parse(fake_response_json)

      @stubs.get('/eligible-letters?icn=DOLLYPARTON') do
        [200, {}, fake_response_body]
      end

      client = Lighthouse::LettersGenerator::Service.new

      response = client.get_eligible_letter_types('DOLLYPARTON')

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

        expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
          .to receive(:get_access_token)
          .once
          .and_return('faketoken')

        fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeBadRequest.json")
        fake_response_body = JSON.parse(fake_response_json)
        @stubs.get('/eligible-letters?icn=BADREQUEST') do
          raise Faraday::BadRequestError.new('YIKES', { status: 400, body: fake_response_body })
        end

        client = Lighthouse::LettersGenerator::Service.new

        expect { client.get_eligible_letter_types('BADREQUEST') }.to raise_error do |error|
          expect(error).to be_an_instance_of(Common::Exceptions::BadRequest)
        end
      end

      it 'handles an error that returns a simplified response' do
        ## This test covers classes of client errors in lighthouse that
        ## have a detailed response, exemplified in fakeBadRequest.json.
        ## Status codes include: 401, 403, 413, 429
        ## Link: https://developer.va.gov/explore/verification/docs/va_letter_generator

        expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
          .to receive(:get_access_token)
          .once
          .and_return('faketoken')

        fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeUnauthorized.json")
        fake_response_body = JSON.parse(fake_response_json)
        @stubs.get('/eligible-letters?icn=BadActor') do
          raise Faraday::UnauthorizedError.new("don't go in there", { status: 401, body: fake_response_body })
        end

        client = Lighthouse::LettersGenerator::Service.new

        expect { client.get_eligible_letter_types('BadActor') }.to raise_error do |error|
          expect(error).to be_an_instance_of(Common::Exceptions::Unauthorized)
        end
      end
    end
  end

  describe '#get_benefit_information' do
    it 'returns a list of benefit information' do
      expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
        .to receive(:get_access_token)
        .once
        .and_return('faketoken')

      fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeResponse.json")
      fake_response_body = JSON.parse(fake_response_json)

      @stubs.get('/eligible-letters?icn=DOLLYPARTON') do
        [200, {}, fake_response_body]
      end

      client = Lighthouse::LettersGenerator::Service.new

      response = client.get_benefit_information('DOLLYPARTON')

      expect(response).to have_key(:benefitInformation)
      expect(response[:benefitInformation]).not_to be_nil
    end

    it 'handles a missing monthlyAwardAmount' do
      expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
        .to receive(:get_access_token)
        .once
        .and_return('faketoken')

      fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeResponse_no_award.json")
      fake_response_body = JSON.parse(fake_response_json)

      @stubs.get('/eligible-letters?icn=DOLLYPARTON') do
        [200, {}, fake_response_body]
      end

      client = Lighthouse::LettersGenerator::Service.new

      response = client.get_benefit_information('DOLLYPARTON')

      expect(response).to have_key(:benefitInformation)
      expect(response[:benefitInformation]).not_to be_nil
      expect(response[:benefitInformation][:monthlyAwardAmount]).to be(0)
    end

    context 'Transformation' do
      it 'performs transformation on benefit info' do
        expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
          .to receive(:get_access_token)
          .once
          .and_return('faketoken')

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
      expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
        .to receive(:get_access_token)
        .once
        .and_return('faketoken')

      fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeResponse.json")
      fake_response_body = JSON.parse(fake_response_json)

      @stubs.get('/letters/BENEFIT_SUMMARY/letter?icn=DOLLYPARTON') do
        [200, {}, fake_response_body]
      end

      client = Lighthouse::LettersGenerator::Service.new
      icns = { icn: 'DOLLYPARTON' }
      response = client.download_letter(icns, 'BENEFIT_SUMMARY')

      @stubs.verify_stubbed_calls
      expect(response).not_to be_nil
    end

    it 'returns a letter pdf with letter options' do
      expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
        .to receive(:get_access_token)
        .once
        .and_return('faketoken')

      fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeResponse.json")
      fake_response_body = JSON.parse(fake_response_json)
      download_path = '/letters/BENEFIT_SUMMARY/letter'
      query_params = 'icn=DOLLYPARTON?serviceConnectedDisabilities=true&chapter35Eligibility=true'

      @stubs.get("#{download_path}?#{query_params}") do
        [200, {}, fake_response_body]
      end

      letter_options = fake_response_body['benefitInformation']

      client = Lighthouse::LettersGenerator::Service.new
      icns = { icn: 'DOLLYPARTON' }
      response = client.download_letter(icns, 'BENEFIT_SUMMARY', letter_options)

      @stubs.verify_stubbed_calls
      expect(response).not_to be_nil
    end

    context 'error handling' do
      it 'handles an error returned from Lighthouse' do
        expect_any_instance_of(Lighthouse::LettersGenerator::Configuration)
          .to receive(:get_access_token)
          .and_return('faketoken')

        fake_response_json = File.read("#{FAKE_RESPONSES_PATH}/fakeBadRequest.json")
        fake_response_body = JSON.parse(fake_response_json)
        @stubs.get('/letters/BENEFIT_SUMMARY/letter?icn=BADREQUEST') do
          raise Faraday::BadRequestError.new('YIKES', { status: 400, body: fake_response_body })
        end

        client = Lighthouse::LettersGenerator::Service.new
        icns = { icn: 'BADREQUEST' }

        expect { client.download_letter(icns, 'BENEFIT_SUMMARY') }.to raise_error do |error|
          expect(error).to be_an_instance_of(Common::Exceptions::BadRequest)
        end
      end
    end
  end
end
