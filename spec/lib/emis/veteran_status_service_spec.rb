# frozen_string_literal: true
require 'rails_helper'
require 'emis/veteran_status_service'
require 'emis/responses/get_veteran_status_response'

# frozen_string_literal: true
require 'emis/service'
require 'emis/veteran_status_configuration'

describe EMIS::VeteranStatusService do
  let(:edipi) { '1607472595' }
  let(:bad_edipi) { '595' }
  let(:missing_edipi) { '1111111111' }

  describe 'get_veteran_status' do
    context 'with a valid request' do
      it 'calls the get_veteran_status endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_veteran_status/valid') do
          response = subject.get_veteran_status(edipi: edipi)
          expect(response).to be_ok
        end
      end

      it 'gives me the right values back' do
        VCR.use_cassette('emis/get_veteran_status/valid') do
          response = subject.get_veteran_status(edipi: edipi)
          expect(response.items.first.title38_status_code).to eq('V4')
          expect(response.items.first.post911_deployment_indicator).to eq('Y')
          expect(response.items.first.post911_combat_indicator).to eq('N')
          expect(response.items.first.pre911_deployment_indicator).to eq('Y')
        end
      end
    end

    context 'with a bad edipi' do
      it 'gives me a bad response' do
        VCR.use_cassette('emis/get_veteran_status/bad_edipi') do
          response = subject.get_veteran_status(edipi: bad_edipi)
          expect(response).not_to be_ok
        end
      end
    end

    context 'with a missing edipi' do
      it 'gives me a missing response' do
        VCR.use_cassette('emis/get_veteran_status/missing_edipi') do
          response = subject.get_veteran_status(edipi: missing_edipi)
          expect(response).not_to be_ok
          expect(response).to be_empty
        end
      end
    end
  end
end

module EMIS
  class BrokenVeteranStatusService < Service
    configuration EMIS::VeteranStatusConfiguration

    create_endpoints([[:get_veteran_status, 'fooRequest']])

    def custom_namespaces
      {}
    end
  end
end

describe EMIS::BrokenVeteranStatusService do
  let(:edipi) { '1607472595' }

  it 'gives me back an error' do
    VCR.use_cassette('emis/get_veteran_status/broken') do
      response = subject.get_veteran_status(edipi: edipi)
      expect(response).to be_an_instance_of(EMIS::Responses::ErrorResponse)
      expect(response.error).to be_an_instance_of(Common::Client::Errors::HTTPError)
    end
  end
end
