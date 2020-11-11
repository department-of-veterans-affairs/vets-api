# frozen_string_literal: true

require 'rails_helper'
require 'emis/mock_veteran_status_service'

describe EMIS::MockVeteranStatusService do
  let(:edipi_veteran) { '1068619536' }
  let(:edipi_non_veteran) { '1140840595' }
  let(:bad_edipi) { '595' }
  let(:missing_edipi) { '1111111111' }
  let(:no_status) { '1005079361' }

  before do
    Settings.vet_verification.mock_emis = true
    Settings.vet_verification.mock_emis_host = 'https://vaausvrsapp81.aac.va.gov'
  end

  describe 'get_veteran_status' do
    context 'with a valid request' do
      it 'calls the get_veteran_status endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_veteran_status/valid') do
          response = subject.get_veteran_status(edipi: edipi_veteran)
          expect(response).to be_ok
        end
      end

      it 'gives me the right values back' do
        VCR.use_cassette('emis/get_veteran_status/valid') do
          response = subject.get_veteran_status(edipi: edipi_veteran)
          expect(response.items.first.title38_status_code).to eq('V1')
          expect(response.items.first.post911_deployment_indicator).to eq('Y')
          expect(response.items.first.post911_combat_indicator).to eq('N')
          expect(response.items.first.pre911_deployment_indicator).to eq('N')
        end
      end
    end

    context 'with a valid request for a non-veteran' do
      it 'gives me the right values back' do
        VCR.use_cassette('emis/get_veteran_status/valid_non_veteran') do
          response = subject.get_veteran_status(edipi: edipi_non_veteran)
          expect(response.items.first.title38_status_code).to eq('V4')
        end
      end
    end

    context 'with a bad edipi' do
      it 'gives me a bad response' do
        VCR.use_cassette('emis/get_veteran_status/bad_edipi') do
          response = subject.get_veteran_status(edipi: bad_edipi)
          expect(response).not_to be_ok
          expect(response.error?).to eq(true)
          expect(response.error).to be_a(EMIS::Errors::ServiceError)
          expect(response.error.message).to eq('MIS-ERR-005 EDIPI_BAD_FORMAT EDIPI incorrectly formatted')
        end
      end
    end

    context 'with a missing edipi' do
      it 'gives me a missing response' do
        VCR.use_cassette('emis/get_veteran_status/missing_edipi') do
          response = subject.get_veteran_status(edipi: missing_edipi)
          expect(response).not_to be_ok
          expect(response).to be_empty
          expect(response.error?).to eq(false)
          expect(response.error).to eq(nil)
        end
      end
    end

    context 'with an empty response element' do
      it 'returns nil' do
        VCR.use_cassette('emis/get_veteran_status/empty_title38') do
          response = subject.get_veteran_status(edipi: no_status)
          expect(response.items.first).to be_nil
        end
      end
    end
  end
end
