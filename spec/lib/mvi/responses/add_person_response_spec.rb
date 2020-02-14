# frozen_string_literal: true

require 'rails_helper'
require 'mvi/responses/add_person_response'
require 'support/mvi/stub_mvi'

describe MVI::Responses::AddPersonResponse do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:body) { Ox.parse(File.read('spec/support/mvi/add_person_response.xml')) }
  let(:ok_response) { described_class.with_parsed_response(faraday_response) }
  let(:error_response) { described_class.with_server_error }
  let(:failed_search) { described_class.with_failed_orch_search(status) }

  before do
    allow(faraday_response).to receive(:body) { body }
  end

  describe '.with_server_error' do
    it 'builds a response with a nil mvi_codes and a status of SERVER_ERROR' do
      expect(error_response.status).to eq('SERVER_ERROR')
      expect(error_response.mvi_codes).to be_nil
    end

    it 'optionally sets #error to the passed exception', :aggregate_failures do
      response = described_class.with_server_error(server_error_exception)
      exception = response.error.errors.first

      expect(response.error).to be_present
      expect(exception.code).to eq server_error_exception.errors.first.code
    end
  end

  describe '.with_failed_orch_search' do
    context 'with an SERVER_ERROR orchestrated search result' do
      let(:status) { 'SERVER_ERROR' }

      it 'builds a response with a nil mvi_codes and a status of SERVER_ERROR' do
        expect(failed_search.status).to eq('SERVER_ERROR')
        expect(failed_search.mvi_codes).to be_nil
      end
    end

    context 'with an NOT_FOUND orchestrated search result' do
      let(:status) { 'NOT_FOUND' }

      it 'builds a response with a nil mvi_codes and a status of NOT_FOUND' do
        expect(failed_search.status).to eq('NOT_FOUND')
        expect(failed_search.mvi_codes).to be_nil
      end
    end

    it 'optionally sets #error to the passed exception', :aggregate_failures do
      response = described_class.with_failed_orch_search('NOT_FOUND', not_found_exception)
      exception = response.error.errors.first

      expect(response.error).to be_present
      expect(exception.code).to eq not_found_exception.errors.first.code
    end
  end

  describe '.with_parsed_response' do
    context 'with a successful response' do
      it 'builds a response with a nil errors a status of OK' do
        expect(ok_response.status).to eq('OK')
        expect(ok_response.error).to be_nil
        expect(ok_response.mvi_codes).to eq(
          [
            { codeSystemName: 'MVI', code: '111985523^PI^200BRLS^USVBA', displayName: 'IEN' },
            { codeSystemName: 'MVI', code: '32397028^PI^200CORP^USVBA', displayName: 'IEN' }
          ]
        )
      end
    end

    context 'with an invalid request response' do
      let(:body) { Ox.parse(File.read('spec/support/mvi/add_person_invalid_response.xml')) }

      it 'raises an invalid request error' do
        expect { described_class.with_parsed_response(faraday_response) }.to raise_error(
          MVI::Errors::InvalidRequestError
        )
      end
    end

    context 'with a failed request response' do
      let(:body) { Ox.parse(File.read('spec/support/mvi/add_person_internal_error_response.xml')) }

      it 'raises a failed request error' do
        expect { described_class.with_parsed_response(faraday_response) }.to raise_error(
          MVI::Errors::FailedRequestError
        )
      end
    end
  end

  describe '#ok?' do
    context 'with a successful response' do
      it 'is true' do
        expect(ok_response).to be_ok
      end
    end

    context 'with an error response' do
      it 'is false' do
        expect(error_response).not_to be_ok
      end
    end
  end

  describe '#server_error?' do
    context 'with a successful response' do
      it 'is true' do
        expect(ok_response).not_to be_server_error
      end
    end

    context 'with an error response' do
      it 'is false' do
        expect(error_response).to be_server_error
      end
    end
  end
end
