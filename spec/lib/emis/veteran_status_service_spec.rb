# frozen_string_literal: true
require 'rails_helper'
require 'emis/veteran_status_service'
require 'emis/responses/get_veteran_status_response'

describe EMIS::VeteranStatusService do
  let(:edipi) { '1607472595' }
  let(:bad_edipi) { '595' }

  describe 'get_veteran_status' do
    context 'with a valid request' do
      it 'calls the get_veteran_status endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_veteran_status/valid') do
          response = subject.get_veteran_status(edipi: edipi)
          expect(response).to be_ok
          # expect(response.profile).to have_deep_attributes(veteran_status)
        end
      end

      it 'gives me the right values back' do
        VCR.use_cassette('emis/get_veteran_status/valid') do
          response = subject.get_veteran_status(edipi: edipi)
          expect(response.title_38_status_code).to eq('V4')
          expect(response).to be_post_911_deployment
          expect(response).to be_pre_911_deployment
          expect(response).not_to be_post_911_combat
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
  end
end
