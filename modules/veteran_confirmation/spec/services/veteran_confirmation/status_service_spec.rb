# frozen_string_literal: true

require 'rails_helper'
require 'mpi/models/mvi_profile'
require 'mpi/service'

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

    let(:ok) { :ok }
    let(:not_found) { :not_found }
    let(:server_error) { :server_error }

    let(:mpi_profile) do
      profile = MPI::Models::MviProfile.new
      profile.edipi = '1005490754'
      response = create(:find_profile_response, profile:)
      response
    end

    let(:not_found_mpi_profile) { create(:find_profile_not_found_response) }
    let(:server_error_mpi_profile) { create(:find_profile_server_error_response, error: MPI::Errors::ServiceError.new) }

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

    let(:empty_veteran_status_response) do
      response = double
      allow(response).to receive(:items).and_return([])
      allow(response).to receive(:error?).and_return(false)
      response
    end

    let(:emis_error) { EMIS::Responses::ErrorResponse.new('Failed in eMIS') }

    context 'when betamocks emis passed valid attributes' do
      before do
        allow(Settings.vet_verification).to receive(:mock_emis).and_return(false)
      end

      it 'confirms veteran status for persons with a title38 status of V1' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile)
        expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status)
          .and_return(veteran_status_response)

        result = subject.get_by_attributes(valid_attributes)
        expect(result).to eq('confirmed')
      end

      it 'does not confirm for title38 status codes other than V1' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile)
        expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status)
          .and_return(non_veteran_status_response)

        result = subject.get_by_attributes(valid_attributes)
        expect(result).to eq('not confirmed')
      end

      it 'raises an exception if MVI returns a server error' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(server_error_mpi_profile)

        expect do
          subject.get_by_attributes(valid_attributes)
        end.to raise_error(MPI::Errors::ServiceError)
      end

      it 'does not confirm if a profile is not found in MVI' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(not_found_mpi_profile)

        result = subject.get_by_attributes(valid_attributes)

        expect(result).to eq('not confirmed')
      end

      it 'does not confirm if EMIS returns an error response' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile)

        expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status)
          .and_return(emis_error)

        result = subject.get_by_attributes(valid_attributes)

        expect(result).to eq('not confirmed')
      end

      it 'does not confirm if EMIS returns an empty response' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile)

        expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status)
          .and_return(empty_veteran_status_response)

        result = subject.get_by_attributes(valid_attributes)

        expect(result).to eq('not confirmed')
      end
    end

    context 'when mock-emis passed valid attributes' do
      before do
        allow(Settings.vet_verification).to receive(:mock_emis).and_return(true)
        allow(Settings.vet_verification).to receive(:mock_emis_host).and_return('https://vaausvrsapp81.aac.va.gov')
      end

      it 'confirms veteran status for persons with a title38 status of V1' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile)
        expect_any_instance_of(EMIS::MockVeteranStatusService).to receive(:get_veteran_status)
          .and_return(veteran_status_response)

        result = subject.get_by_attributes(valid_attributes)
        expect(result).to eq('confirmed')
      end

      it 'does not confirm for title38 status codes other than V1' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile)
        expect_any_instance_of(EMIS::MockVeteranStatusService).to receive(:get_veteran_status)
          .and_return(non_veteran_status_response)

        result = subject.get_by_attributes(valid_attributes)
        expect(result).to eq('not confirmed')
      end

      it 'raises an exception if MVI returns a server error' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(server_error_mpi_profile)

        expect do
          subject.get_by_attributes(valid_attributes)
        end.to raise_error(MPI::Errors::ServiceError)
      end

      it 'does not confirm if a profile is not found in MVI' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(not_found_mpi_profile)

        result = subject.get_by_attributes(valid_attributes)

        expect(result).to eq('not confirmed')
      end

      it 'does not confirm if EMIS returns an error response' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile)

        expect_any_instance_of(EMIS::MockVeteranStatusService).to receive(:get_veteran_status)
          .and_return(emis_error)

        result = subject.get_by_attributes(valid_attributes)

        expect(result).to eq('not confirmed')
      end
    end
  end
end
