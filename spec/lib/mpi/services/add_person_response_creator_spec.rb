# frozen_string_literal: true

require 'rails_helper'
require 'mpi/services/add_person_response_creator'

describe MPI::Services::AddPersonResponseCreator do
  describe '#perform' do
    subject { described_class.new(type:, response:, error:).perform }

    let(:type) { 'some-type' }
    let(:response) { 'some-response' }
    let(:error) { 'some-error' }

    shared_examples 'error response' do
      let(:expected_error_message) { "MPI #{type} response error" }
      let(:sentry_context) { { error_message: expected_error.message } }
      let(:sentry_log_level) { :warn }
      let(:expected_status) { :server_error }

      it 'logs error to sentry' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(expected_error_message,
                                                                                      sentry_log_level,
                                                                                      sentry_context)
        subject
      end

      it 'returns an add person response with expected status' do
        expect(subject.status).to eq(expected_status)
      end

      it 'returns an add person response with expected error' do
        expect(subject.error).to eq(expected_error)
      end
    end

    context 'when error is given in params' do
      let(:error) { StandardError.new(error_message) }
      let(:error_message) { 'some-error-message' }

      context 'and response is given in params' do
        let(:response) { 'some-response' }
        let(:expected_error) { MPI::Errors::InvalidResponseParamsError }

        it 'raises an invalid response params error' do
          expect { subject }.to raise_error(expected_error)
        end
      end

      context 'and response is not given in params' do
        let(:response) { nil }
        let(:expected_error) { error }

        it_behaves_like 'error response'
      end
    end

    context 'when error is not given in params' do
      let(:error) { nil }

      context 'and response is given in params with invalid request status' do
        let(:response) do
          OpenStruct.new({ body: Ox.parse(File.read('spec/support/mpi/add_person_invalid_response.xml')),
                           response_headers: {} })
        end
        let(:mpi_codes) do
          { other: [{ codeSystem: '2.16.840.1.113883.5.1100', code: 'INTERR', displayName: 'Internal System Error' }] }
        end
        let(:error_details) do
          { other: mpi_codes[:other],
            transaction_id: nil,
            error_details: { ack_detail_code:,
                             id_extension: '200VGOV-1373004c-e23e-4d94-90c5-5b101f6be54a',
                             error_texts: ['Internal System Error'] } }
        end
        let(:ack_detail_code) { 'AE' }
        let(:expected_error) { MPI::Errors::InvalidRequestError.new(error_details) }

        it_behaves_like 'error response'
      end

      context 'when response is given in params with failed request status' do
        let(:response) do
          OpenStruct.new({ body: Ox.parse(File.read('spec/support/mpi/add_person_internal_error_response.xml')),
                           response_headers: {} })
        end
        let(:mpi_codes) do
          { other: [{ codeSystem: '2.16.840.1.113883.5.1100', code: 'INTERR', displayName: 'Internal System Error' }] }
        end
        let(:error_details) do
          { other: mpi_codes[:other],
            transaction_id: nil,
            error_details: { ack_detail_code:,
                             id_extension: '200VGOV-1373004c-e23e-4d94-90c5-5b101f6be54a',
                             error_texts: ['Internal System Error'] } }
        end
        let(:ack_detail_code) { 'AR' }
        let(:expected_error) { MPI::Errors::FailedRequestError.new(error_details) }

        it_behaves_like 'error response'
      end

      context 'when response is given in params with success request status' do
        let(:response) do
          OpenStruct.new({ body: Ox.parse(File.read('spec/support/mpi/add_person_response.xml')),
                           response_headers: { 'x-global-transaction-id' => transaction_id } })
        end
        let(:transaction_id) { 'some-transaction-id' }
        let(:expected_log) do
          "[MPI][Services][AddPersonResponseCreator] #{type}, " \
            'icn=, ' \
            'idme_uuid=, ' \
            'logingov_uuid=, ' \
            "transaction_id=#{transaction_id}"
        end
        let(:birls_id) { '111985523' }
        let(:participant_id) { '32397028' }

        it 'logs a message to rails logger' do
          expect(Rails.logger).to receive(:info).with(expected_log)
          subject
        end

        it 'creates an add person response with an ok status' do
          expect(subject.status).to eq(:ok)
        end

        it 'creates an add person response with expected parsed codes' do
          expect(subject.parsed_codes).to eq(
            {
              birls_id:,
              participant_id:,
              transaction_id:
            }
          )
        end
      end

      context 'and response is not given in params' do
        let(:response) { nil }
        let(:expected_error) { MPI::Errors::InvalidResponseParamsError }

        it 'raises an invalid response params error' do
          expect { subject }.to raise_error(expected_error)
        end
      end
    end
  end
end
