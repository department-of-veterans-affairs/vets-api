# frozen_string_literal: true

require 'rails_helper'
require 'mpi/services/find_profile_response_creator'

describe MPI::Services::FindProfileResponseCreator do
  describe '#perform' do
    subject { described_class.new(type:, response:, error:).perform }

    let(:type) { 'some-type' }
    let(:response) { 'some-response' }
    let(:error) { 'some-error' }

    shared_examples 'error response' do
      let(:expected_error_message) { "MPI #{type} response error" }
      let(:error_details) do
        { error_details: { ack_detail_code:,
                           id_extension:,
                           transaction_id:,
                           error_texts: } }
      end
      let(:sentry_context) { { error_message: expected_error.message } }
      let(:sentry_log_level) { :warn }

      it 'logs error to sentry' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(expected_error_message,
                                                                                      sentry_log_level,
                                                                                      sentry_context)
        subject
      end

      it 'returns a find profile response with expected status' do
        expect(subject.status).to eq(expected_status)
      end

      it 'returns a find profile response with expected error' do
        expect(subject.error).to eq(expected_error)
      end
    end

    shared_examples 'record not found error response' do
      let(:expected_error_message) { "[MPI][Services][FindProfileResponseCreator] #{type} #{detailed_error_message}" }
      let(:error_details) do
        { error_details: { ack_detail_code:,
                           id_extension:,
                           transaction_id:,
                           error_texts: } }
      end
      let(:detailed_error_message) { "Record Not Found, transaction_id=#{transaction_id}" }

      it 'logs message to rails logger' do
        expect(Rails.logger).to receive(:info).with(expected_error_message)
        subject
      end

      it 'returns a find profile response with expected status' do
        expect(subject.status).to eq(expected_status)
      end

      it 'returns a find profile response with expected error' do
        expect(subject.error).to eq(expected_error)
      end
    end

    context 'when error is given in params' do
      let(:error) { StandardError.new(error_message) }
      let(:error_message) { 'some-error-message' }
      let(:expected_status) { :server_error }

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
      let(:transaction_id) { 'some-transaction-id' }
      let(:response_file) { 'some-response-file' }
      let(:response) do
        OpenStruct.new({ body: Ox.parse(response_file),
                         response_headers: { 'x-global-transaction-id' => transaction_id } })
      end

      context 'and response is given in params with invalid request status' do
        let(:response_file) { File.read('spec/support/mpi/find_candidate_invalid_response.xml') }
        let(:id_extension) { '200VGOV-2c3c0c78-5e44-4ad2-b542-11388c3e45cd' }
        let(:error_texts) { ['MVI[S]:INVALID REQUEST'] }
        let(:ack_detail_code) { 'AE' }
        let(:expected_error) { MPI::Errors::RecordNotFound.new(error_details) }
        let(:expected_status) { :not_found }

        it_behaves_like 'record not found error response'
      end

      context 'when response is given in params with failed request status' do
        let(:response_file) { File.read('spec/support/mpi/find_candidate_ar_code_database_error_response.xml') }
        let(:id_extension) { 'MCID-12345' }
        let(:error_texts) { ['Environment Database Error'] }
        let(:ack_detail_code) { 'AR' }
        let(:expected_error) { MPI::Errors::FailedRequestError.new(error_details) }
        let(:expected_status) { :server_error }

        it_behaves_like 'error response'
      end

      context 'when response is given in params with multiple match status' do
        let(:response_file) { File.read('spec/support/mpi/find_candidate_multiple_match_response.xml') }
        let(:id_extension) { '200VGOV-03b2801a-3005-4dcc-9a3c-7e3e4c0d5293' }
        let(:error_texts) { ['Multiple Matches Found'] }
        let(:ack_detail_code) { 'AE' }
        let(:expected_error) { MPI::Errors::DuplicateRecords.new(error_details) }
        let(:expected_status) { :not_found }

        it_behaves_like 'error response'
      end

      context 'when response is given in params with no match status' do
        let(:response_file) { File.read('spec/support/mpi/find_candidate_no_match_response.xml') }
        let(:id_extension) { nil }
        let(:error_texts) { [] }
        let(:ack_detail_code) { nil }
        let(:expected_error) { MPI::Errors::RecordNotFound.new(error_details) }
        let(:expected_status) { :not_found }

        it_behaves_like 'record not found error response'
      end

      context 'and response is given in params with unknown error' do
        let(:response_file) { File.read('spec/support/mpi/find_candidate_soap_fault.xml') }
        let(:id_extension) { nil }
        let(:error_texts) { [] }
        let(:ack_detail_code) { nil }
        let(:expected_error) { MPI::Errors::RecordNotFound.new(error_details) }
        let(:expected_status) { :not_found }

        it_behaves_like 'record not found error response'
      end

      context 'when response is given in params with success request status' do
        let(:response_file) { File.read('spec/support/mpi/find_candidate_response.xml') }
        let(:expected_icn) { '1000123456V123456' }
        let(:expected_birth_date) { '19800101' }
        let(:expected_edipi) { '1234567890' }
        let(:expected_last_name) { 'Smith' }
        let(:expected_first_name) { 'John' }
        let(:expected_ssn) { '555443333' }
        let(:expected_log) do
          "[MPI][Services][FindProfileResponseCreator] #{type} " \
            "icn=#{expected_icn}, " \
            "transaction_id=#{transaction_id}"
        end

        it 'logs a message to rails logger' do
          expect(Rails.logger).to receive(:info).with(expected_log)
          subject
        end

        it 'creates a find profile response with an ok status' do
          expect(subject.status).to eq(:ok)
        end

        it 'creates a find profile response with expected attributes' do
          expect(subject.profile.icn).to eq(expected_icn)
          expect(subject.profile.birth_date).to eq(expected_birth_date)
          expect(subject.profile.edipi).to eq(expected_edipi)
          expect(subject.profile.family_name).to eq(expected_last_name)
          expect(subject.profile.given_names.first).to eq(expected_first_name)
          expect(subject.profile.ssn).to eq(expected_ssn)
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
