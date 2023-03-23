# frozen_string_literal: true

require 'rails_helper'
require 'emis/military_information_service'

describe EMIS::MilitaryInformationService do
  describe 'get_deployment' do
    let(:edipi) { '1607472595' }

    context 'with a valid request' do
      it 'calls the get_deplopyment endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_deployment/valid') do
          response = subject.get_deployment(edipi:)
          expect(response).to be_ok
        end
      end
    end
  end

  describe 'get_disabilities' do
    let(:edipi) { '6001010001' }

    context 'with a valid request' do
      it 'calls the get_disabilities endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_disabilities/valid') do
          response = subject.get_disabilities(edipi:)
          expect(response).to be_ok
        end
      end
    end
  end

  describe 'get_guard_reserve_service_periods' do
    let(:edipi) { '1607472595' }

    context 'with a valid request' do
      it 'calls the get_guard_reserve_service_periods endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_guard_reserve_service_periods/valid') do
          response = subject.get_guard_reserve_service_periods(edipi:)
          expect(response).to be_ok
        end
      end
    end
  end

  describe 'get_military_service_eligibility_info' do
    let(:edipi) { '1607472595' }

    context 'with a valid request' do
      it 'calls the get_military_service_eligibility_info endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_military_service_eligibility_info/valid') do
          response = subject.get_military_service_eligibility_info(edipi:)
          expect(response).to be_ok
        end
      end
    end
  end

  describe 'get_military_occupation' do
    let(:edipi) { '1606109357' }

    context 'with a valid request' do
      it 'calls the get_military_occupation endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_military_occupation/valid') do
          response = subject.get_military_occupation(edipi:)
          expect(response).to be_ok
        end
      end
    end
  end

  describe 'get_military_service_episodes' do
    context 'with a valid request' do
      let(:edipi) { '1607472595' }

      it 'calls the get_military_service_episodes endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_military_service_episodes/valid') do
          response = subject.get_military_service_episodes(edipi:)
          expect(response).to be_ok
        end
      end
    end

    context 'with a valid request for episodes with no end date' do
      let(:edipi) { '1005123832' }

      it 'calls the get_military_service_episodes endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_military_service_episodes/valid_no_end_date') do
          response = subject.get_military_service_episodes(edipi:)
          expect(response).to be_ok
        end
      end
    end
  end

  describe 'get_retirement' do
    let(:edipi) { '6001011005' }

    context 'with a valid request' do
      it 'calls the get_retirement endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_retirement/valid') do
          response = subject.get_retirement(edipi:)
          expect(response).to be_ok
        end
      end
    end
  end

  describe 'get_unit_information' do
    let(:edipi) { '6001010001' }

    context 'with a valid request' do
      it 'calls the get_unit_information endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_unit_information/valid') do
          response = subject.get_unit_information(edipi:)
          expect(response).to be_ok
        end
      end
    end
  end
end
