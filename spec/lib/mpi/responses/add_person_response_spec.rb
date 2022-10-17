# frozen_string_literal: true

require 'rails_helper'
require 'mpi/responses/add_person_response'

describe MPI::Responses::AddPersonResponse do
  let(:faraday_response) { instance_double('Faraday::Env') }
  let(:headers) { { 'x-global-transaction-id' => transaction_id } }
  let(:transaction_id) { 'some-transaction-id' }
  let(:body) { Ox.parse(File.read('spec/support/mpi/add_person_response.xml')) }
  let(:type) { 'some-type' }

  before do
    allow(faraday_response).to receive(:body) { body }
    allow(faraday_response).to receive(:response_headers) { headers }
  end

  describe '.with_server_error' do
    subject { described_class.with_server_error }

    it 'builds a response with a nil mvi_codes and a status of SERVER_ERROR' do
      expect(subject.status).to eq('SERVER_ERROR')
      expect(subject.mvi_codes).to be_nil
    end

    it 'optionally sets #error to the passed exception', :aggregate_failures do
      response = described_class.with_server_error(server_error_exception)
      exception = response.error.errors.first

      expect(response.error).to be_present
      expect(exception.code).to eq server_error_exception.errors.first.code
    end
  end

  describe '.with_failed_orch_search' do
    subject { described_class.with_failed_orch_search(status) }

    context 'with an SERVER_ERROR orchestrated search result' do
      let(:status) { 'SERVER_ERROR' }

      it 'builds a response with a nil mvi_codes and a status of SERVER_ERROR' do
        expect(subject.status).to eq('SERVER_ERROR')
        expect(subject.mvi_codes).to be_nil
      end
    end

    context 'with an NOT_FOUND orchestrated search result' do
      let(:status) { 'NOT_FOUND' }

      it 'builds a response with a nil mvi_codes and a status of NOT_FOUND' do
        expect(subject.status).to eq('NOT_FOUND')
        expect(subject.mvi_codes).to be_nil
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
    subject { described_class.with_parsed_response(type, faraday_response) }

    let(:error_details) do
      { other: [{ codeSystem: '2.16.840.1.113883.5.1100',
                  code: 'INTERR',
                  displayName: 'Internal System Error' }],
        transaction_id: transaction_id,
        error_details: { ack_detail_code: ack_detail_code,
                         id_extension: '200VGOV-1373004c-e23e-4d94-90c5-5b101f6be54a',
                         error_texts: ['Internal System Error'] } }
    end

    context 'with a successful response' do
      let(:expected_log) do
        "[MPI][Responses][AddPersonResponse] #{type}, " \
          'icn=, ' \
          'idme_uuid=, ' \
          'logingov_uuid=, ' \
          "transaction_id=#{transaction_id}"
      end

      it 'logs a message to rails logger' do
        expect(Rails.logger).to receive(:info).with(expected_log)
        subject
      end

      it 'builds a response with a nil errors a status of OK' do
        expect(subject.status).to eq('OK')
        expect(subject.error).to be_nil
        expect(subject.mvi_codes).to eq(
          {
            birls_id: '111985523',
            participant_id: '32397028',
            transaction_id: transaction_id
          }
        )
      end
    end

    context 'with an invalid request response' do
      let(:body) { Ox.parse(File.read('spec/support/mpi/add_person_invalid_response.xml')) }
      let(:ack_detail_code) { 'AE' }

      it 'raises an invalid request error with parsed details from MPI' do
        expect { described_class.with_parsed_response(type, faraday_response) }.to raise_error(
          MPI::Errors::InvalidRequestError, error_details.to_s
        )
      end
    end

    context 'with a failed request response' do
      let(:body) { Ox.parse(File.read('spec/support/mpi/add_person_internal_error_response.xml')) }
      let(:ack_detail_code) { 'AR' }

      it 'raises a failed request error with parsed details from MPI' do
        expect { described_class.with_parsed_response(type, faraday_response) }.to raise_error(
          MPI::Errors::FailedRequestError, error_details.to_s
        )
      end
    end
  end

  describe '#ok?' do
    context 'with a successful response' do
      subject { described_class.with_parsed_response(type, faraday_response).ok? }

      it 'is true' do
        expect(subject).to be true
      end
    end

    context 'with an error response' do
      subject { described_class.with_server_error.ok? }

      it 'is false' do
        expect(subject).to be false
      end
    end
  end

  describe '#server_error?' do
    context 'with a successful response' do
      subject { described_class.with_parsed_response(type, faraday_response).server_error? }

      it 'is false' do
        expect(subject).to be false
      end
    end

    context 'with an error response' do
      subject { described_class.with_server_error.server_error? }

      it 'is true' do
        expect(subject).to be true
      end
    end
  end
end
