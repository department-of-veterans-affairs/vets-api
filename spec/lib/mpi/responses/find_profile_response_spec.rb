# frozen_string_literal: true

require 'rails_helper'
require 'mpi/responses/find_profile_response'

describe MPI::Responses::FindProfileResponse do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_response.xml')) }
  let(:mpi_response) { MPI::Responses::FindProfileResponse.with_parsed_response(faraday_response) }
  let(:error_response) { MPI::Responses::FindProfileResponse.with_server_error }
  let(:not_found_response) { MPI::Responses::FindProfileResponse.with_not_found }
  let(:ack_detail_code) { 'AE' }
  let(:error_details) do
    { error_details: { ack_detail_code: ack_detail_code,
                       id_extension: id_extension,
                       error_texts: error_texts } }
  end

  before do
    allow(faraday_response).to receive(:body) { body }
  end

  describe '.with_parsed_response' do
    context 'with a successful response' do
      it 'builds a response with a nil errors a status of OK' do
        expect(mpi_response.status).to eq('OK')
        expect(mpi_response.error).to be_nil
        expect(mpi_response.profile.full_mvi_ids).to eq(
          ['1000123456V123456^NI^200M^USVHA^P',
           '12345^PI^516^USVHA^PCE',
           '2^PI^553^USVHA^PCE',
           '12345^PI^200HD^USVHA^A',
           'TKIP123456^PI^200IP^USVHA^A',
           '123456^PI^200MHV^USVHA^A',
           '1234567890^NI^200DOD^USDOD^A',
           '87654321^PI^200CORP^USVBA^H',
           '12345678^PI^200CORP^USVBA^A',
           '123456789^PI^200VETS^USDVA^A']
        )
      end
    end

    context 'with an invalid request response' do
      let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_invalid_response.xml')) }
      let(:id_extension) { '200VGOV-2c3c0c78-5e44-4ad2-b542-11388c3e45cd' }
      let(:error_texts) { ['MVI[S]:INVALID REQUEST'] }

      it 'raises an invalid request error' do
        expect { mpi_response }.to raise_error(MPI::Errors::InvalidRequestError, error_details.to_s)
      end
    end

    context 'with a multiple match request response' do
      let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_multiple_match_response.xml')) }
      let(:id_extension) { '200VGOV-03b2801a-3005-4dcc-9a3c-7e3e4c0d5293' }
      let(:error_texts) { ['Multiple Matches Found'] }

      it 'raises an duplicate records error' do
        expect { mpi_response }.to raise_error(MPI::Errors::DuplicateRecords, error_details.to_s)
      end
    end

    context 'with a malformed request response' do
      let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_soap_fault.xml')) }

      it 'raises a record not found error' do
        expect { mpi_response }.to raise_error(MPI::Errors::RecordNotFound)
      end
    end

    context 'with a system error response' do
      let(:body) do
        Ox.parse(File.read('spec/support/mpi/find_candidate_ar_code_database_error_response.xml'))
      end
      let(:ack_detail_code) { 'AR' }
      let(:id_extension) { 'MCID-12345' }
      let(:error_texts) { ['Environment Database Error'] }

      it 'raises a record not found error' do
        expect { mpi_response }.to raise_error(MPI::Errors::FailedRequestError, error_details.to_s)
      end
    end
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

  describe '#ok?' do
    context 'with a successful response' do
      it 'is true' do
        expect(mpi_response).to be_ok
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
        expect(mpi_response).not_to be_not_found
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
        expect(mpi_response).not_to be_server_error
      end
    end

    context 'with an error response' do
      it 'is false' do
        expect(error_response).to be_server_error
      end
    end
  end
end
