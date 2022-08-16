# frozen_string_literal: true

require 'rails_helper'
require 'mpi/responses/add_person_response'

describe MPI::Responses::AddPersonResponse do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:body) { Ox.parse(File.read('spec/support/mpi/add_person_response.xml')) }
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
    let(:error_details) do
      { other: [{ codeSystem: '2.16.840.1.113883.5.1100',
                  code: 'INTERR',
                  displayName: 'Internal System Error' }],
        error_details: { ack_detail_code: ack_detail_code,
                         id_extension: '200VGOV-1373004c-e23e-4d94-90c5-5b101f6be54a',
                         error_texts: ['Internal System Error'] } }
    end

    context 'with a successful response' do
      it 'builds a response with a nil errors a status of OK' do
        expect(ok_response.status).to eq('OK')
        expect(ok_response.error).to be_nil
        expect(ok_response.mvi_codes).to eq(
          {
            birls_id: '111985523',
            participant_id: '32397028'
          }
        )
      end
    end

    context 'with an invalid request response' do
      let(:body) { Ox.parse(File.read('spec/support/mpi/add_person_invalid_response.xml')) }
      let(:ack_detail_code) { 'AE' }

      it 'raises an invalid request error with parsed details from MPI' do
        expect { described_class.with_parsed_response(faraday_response) }.to raise_error(
          MPI::Errors::InvalidRequestError, error_details.to_s
        )
      end
    end

    context 'with a failed request response' do
      let(:body) { Ox.parse(File.read('spec/support/mpi/add_person_internal_error_response.xml')) }
      let(:ack_detail_code) { 'AR' }

      it 'raises a failed request error with parsed details from MPI' do
        expect { described_class.with_parsed_response(faraday_response) }.to raise_error(
          MPI::Errors::FailedRequestError, error_details.to_s
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
