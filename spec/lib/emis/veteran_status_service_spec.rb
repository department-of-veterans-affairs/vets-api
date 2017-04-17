# frozen_string_literal: true
require 'rails_helper'
require 'emis/veteran_status_service'
require 'emis/responses/get_veteran_status_response'

describe EMIS::VeteranStatusService do
  let(:edipi) { Faker::Number.number(10) }

  describe 'get_veteran_status' do
    context 'with a valid request' do
      it 'calls the get_veteran_status endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_veteran_status/valid') do
          response = subject.get_veteran_status(edipi)
          expect(response.status).to eq('OK')
          expect(response.profile).to have_deep_attributes(veteran_status)
        end
      end
    end
  end
end
