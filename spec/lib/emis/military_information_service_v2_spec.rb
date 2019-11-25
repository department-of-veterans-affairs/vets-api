# frozen_string_literal: true

require 'rails_helper'
require 'emis/military_information_service'

describe EMIS::MilitaryInformationServiceV2 do
  describe 'get_military_service_episodes' do
    context 'with a valid request' do
      let(:edipi) { '1607472595' }

      it 'calls the get_military_service_episodes endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_military_service_episodes/valid_v2') do
          response = subject.get_military_service_episodes(edipi: edipi)
          expect(response).to be_ok
        end
      end
    end

    context 'with a valid request for episodes with no end date' do
      let(:edipi) { '1005123832' }

      it 'calls the get_military_service_episodes endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_military_service_episodes/valid_no_end_date_v2') do
          response = subject.get_military_service_episodes(edipi: edipi)
          expect(response).to be_ok
        end
      end
    end
  end
end
