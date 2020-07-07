# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VeteranConfirmation::StatusService do
  describe '.get_by_attributes' do
    let(:valid_attributes) do
      {
        ssn: '123456789',
        first_name: 'John',
        last_name: 'Doe',
        birth_date: Date.iso8601('1967-04-13').strftime('%Y%m%d')
      }
    end

    let(:ok) { MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok] }
    let(:not_found) { MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:not_found] }
    let(:server_error) { MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:server_error] }

    let(:mpi_profile) do
      profile = MPI::Models::MPIProfile.new
      profile.edipi = '1005490754'
      response = MPI::Responses::FindProfileResponse.new
      response.profile = profile
      response.status = ok
      response
    end

    let(:not_found_mpi_profile) do
      response = MPI::Responses::FindProfileResponse.new
      response.status = not_found
      response
    end

    let(:server_error_mpi_profile) do
      response = MPI::Responses::FindProfileResponse.new
      response.status = server_error
      response.error = MPI::Errors::ServiceError.new
      response
    end

    let(:veteran_status_response) do
      response = double
      model = EMIS::Models::VeteranStatus.new
      model.title38_status_code = 'V1'
      allow(response).to receive(:items).and_return([model])
      allow(response).to receive(:error?).and_return(false)
      response
    end

    let(:non_veteran_status_response) do
      response = double
      model = EMIS::Models::VeteranStatus.new
      model.title38_status_code = 'other'
      allow(response).to receive(:items).and_return([model])
      allow(response).to receive(:error?).and_return(false)
      response
    end

    let(:emis_error) { EMIS::Responses::ErrorResponse.new('Failed in eMIS') }

    context 'when passed valid attributes' do
      it 'confirms veteran status for persons with a title38 status of V1' do
        expect_any_instance_of(MPI::AttrService).to receive(:find_profile)
          .and_return(mpi_profile)
        expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status)
          .and_return(veteran_status_response)

        result = subject.get_by_attributes(valid_attributes)
        expect(result).to eq('confirmed')
      end

      it 'does not confirm for title38 status codes other than V1' do
        expect_any_instance_of(MPI::AttrService).to receive(:find_profile)
          .and_return(mpi_profile)
        expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status)
          .and_return(non_veteran_status_response)

        result = subject.get_by_attributes(valid_attributes)
        expect(result).to eq('not confirmed')
      end

      it 'raises an exception if MVI returns a server error' do
        expect_any_instance_of(MPI::AttrService).to receive(:find_profile)
          .and_return(server_error_mpi_profile)

        expect do
          subject.get_by_attributes(valid_attributes)
        end.to raise_error(MPI::Errors::ServiceError)
      end

      it 'does not confirm if a profile is not found in MVI' do
        expect_any_instance_of(MPI::AttrService).to receive(:find_profile)
          .and_return(not_found_mpi_profile)

        result = subject.get_by_attributes(valid_attributes)

        expect(result).to eq('not confirmed')
      end

      it 'does not confirm if EMIS returns an error response' do
        expect_any_instance_of(MPI::AttrService).to receive(:find_profile)
          .and_return(mpi_profile)

        expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status)
          .and_return(emis_error)

        result = subject.get_by_attributes(valid_attributes)

        expect(result).to eq('not confirmed')
      end
    end
  end
end
