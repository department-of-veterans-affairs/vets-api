# frozen_string_literal: true

require 'rails_helper'
require 'mpi/responses/find_profile_response'

describe MPI::Responses::FindProfileResponse do
  let(:raw_response) { OpenStruct.new({ body: body, response_headers: headers }) }
  let(:headers) { { 'x-global-transaction-id' => transaction_id } }
  let(:transaction_id) { 'some-transaction-id' }
  let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_response.xml')) }
  let(:ok_response) { MPI::Responses::FindProfileResponse.with_parsed_response(raw_response) }
  let(:error_response) { MPI::Responses::FindProfileResponse.with_server_error }
  let(:not_found_response) { MPI::Responses::FindProfileResponse.with_not_found }
  let(:ack_detail_code) { 'AE' }
  let(:error_details) do
    { error_details: { ack_detail_code: ack_detail_code,
                       id_extension: id_extension,
                       error_texts: error_texts } }
  end

  describe '.with_server_error' do
    it 'builds a response with a nil profile and a status of SERVER_ERROR' do
      expect(error_response.status).to eq('SERVER_ERROR')
      expect(error_response.profile).to be_nil
    end

    it 'optionally sets #error to the passed exception', :aggregate_failures do
      response  = MPI::Responses::FindProfileResponse.with_server_error(server_error_exception)
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
      response  = MPI::Responses::FindProfileResponse.with_not_found(not_found_exception)
      exception = response.error.errors.first

      expect(response.error).to be_present
      expect(exception.code).to eq not_found_exception.errors.first.code
    end
  end

  describe '.with_parsed_response' do
    subject { described_class.with_parsed_response(raw_response) }

    context 'with no profile' do
      before do
        allow_any_instance_of(MPI::Responses::ProfileParser).to receive(:parse).and_return(nil)
      end

      it 'sends mpi transaction id to raven extra context' do
        expect(Raven).to receive(:extra_context).with(
          mpi_transaction_id: 'f8ba531562ec2fa1098a9c93'
        )

        expect do
          described_class.with_parsed_response(
            OpenStruct.new(
              response_headers: {
                'x-backside-transport' => 'OK OK,OK OK',
                'transfer-encoding' => 'chunked',
                'date' => 'Thu, 04 Aug 2022 20:44:28 GMT',
                'content-type' => 'text/xml',
                'x-global-transaction-id' => 'f8ba531562ec2fa1098a9c93'
              }
            )
          )
        end.to raise_error(MPI::Errors::RecordNotFound)
      end
    end

    context 'when response parses multiple match' do
      let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_multiple_match_response.xml')) }
      let(:expected_error) { MPI::Errors::DuplicateRecords }
      let(:id_extension) { '200VGOV-03b2801a-3005-4dcc-9a3c-7e3e4c0d5293' }
      let(:error_texts) { ['Multiple Matches Found'] }

      it 'raises a duplicate records exception' do
        expect { subject }.to raise_exception(expected_error, error_details.to_s)
      end
    end

    context 'when response parses invalid request' do
      let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_invalid_request.xml')) }
      let(:expected_error) { MPI::Errors::RecordNotFound }

      it 'raises a record not found exception' do
        expect { subject }.to raise_exception(expected_error)
      end
    end

    context 'when response parses failed request' do
      let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_ar_code_database_error_response.xml')) }
      let(:ack_detail_code) { 'AR' }
      let(:id_extension) { 'MCID-12345' }
      let(:error_texts) { ['Environment Database Error'] }
      let(:expected_error) { MPI::Errors::FailedRequestError }

      it 'raises a failed request error' do
        expect { subject }.to raise_exception(expected_error, error_details.to_s)
      end
    end

    context 'when response parses as nil' do
      let(:body) { nil }
      let(:expected_error) { MPI::Errors::RecordNotFound }

      it 'raises a record not found exception' do
        expect { subject }.to raise_exception(expected_error)
      end
    end

    context 'successful parsing of response' do
      let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_response.xml')) }
      let(:expected_status) { Common::Client::Concerns::ServiceStatus::RESPONSE_STATUS[:ok] }
      let(:expected_parsed_profile) { MPI::Responses::ProfileParser.new(raw_response).parse }
      let(:icn) { expected_parsed_profile.icn }
      let(:expected_log) { "[MPI][Responses][FindProfileResponse] icn=#{icn}, transaction_id=#{transaction_id}" }

      it 'logs a message to rails logger' do
        expect(Rails.logger).to receive(:info).with(expected_log)
        subject
      end

      it 'returns profile response with ok status' do
        expect(subject.status).to eq(expected_status)
      end

      it 'returns profile response with parsed profile' do
        expect(subject.profile).to have_deep_attributes(expected_parsed_profile)
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

  describe '#not_found?' do
    context 'with a successful response' do
      it 'is true' do
        expect(ok_response).not_to be_not_found
      end
    end

    context 'with a not found response' do
      it 'is false' do
        expect(not_found_response).to be_not_found
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
