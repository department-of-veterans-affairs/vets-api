# frozen_string_literal: true

require 'rails_helper'
require 'mvi/responses/find_profile_response'
require 'support/mvi/stub_mvi'

describe MVI::Responses::FindProfileResponse do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:body) { Ox.parse(File.read('spec/support/mvi/find_candidate_response.xml')) }
  let(:ok_response) { MVI::Responses::FindProfileResponse.with_parsed_response(faraday_response) }
  let(:error_response) { MVI::Responses::FindProfileResponse.with_server_error }
  let(:not_found_response) { MVI::Responses::FindProfileResponse.with_not_found }

  before(:each) do
    allow(faraday_response).to receive(:body) { body }
  end

  describe '.with_server_error' do
    it 'builds a response with a nil profile and a status of SERVER_ERROR' do
      expect(error_response.status).to eq('SERVER_ERROR')
      expect(error_response.profile).to be_nil
    end

    it 'optionally sets #error to the passed exception', :aggregate_failures do
      response  = MVI::Responses::FindProfileResponse.with_server_error(server_error_exception)
      exception = response.error.errors.first

      expect(response.error).to be_present
      expect(exception.code).to eq server_error_exception.errors.first.code
    end
  end

  describe '.with_not_found' do
    it 'builds a response with a nil profile and a status of NOT_FOUND' do
      expect(not_found_response.status).to eq('NOT_FOUND')
      expect(not_found_response.profile).to be_nil
    end

    it 'optionally sets #error to the passed exception', :aggregate_failures do
      response  = MVI::Responses::FindProfileResponse.with_not_found(not_found_exception)
      exception = response.error.errors.first

      expect(response.error).to be_present
      expect(exception.code).to eq not_found_exception.errors.first.code
    end
  end

  describe '#ok?' do
    context 'with a successful response' do
      it 'should be true' do
        expect(ok_response).to be_ok
      end
    end

    context 'with an error response' do
      it 'should be false' do
        expect(error_response).not_to be_ok
      end
    end
  end

  describe '#not_found?' do
    context 'with a successful response' do
      it 'should be true' do
        expect(ok_response).not_to be_not_found
      end
    end

    context 'with a not found response' do
      it 'should be false' do
        expect(not_found_response).to be_not_found
      end
    end
  end

  describe '#server_error?' do
    context 'with a successful response' do
      it 'should be true' do
        expect(ok_response).not_to be_server_error
      end
    end

    context 'with an error response' do
      it 'should be false' do
        expect(error_response).to be_server_error
      end
    end
  end
end
