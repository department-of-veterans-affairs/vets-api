# frozen_string_literal: true

require 'rails_helper'
# these requires are needed to stub values for tests (they won't normally be laoded until the class is exercised)
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

    let(:ok) { MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok] }
    let(:not_found) { MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:not_found] }
    let(:server_error) { MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:server_error] }

    let(:mvi_profile) do
      profile = MPI::Models::MviProfile.new
      profile.edipi = '1005490754'
      response = MPI::Responses::FindProfileResponse.new
      response.profile = profile
      response.status = ok
      response
    end

    let(:not_found_mvi_profile) do
      response = MPI::Responses::FindProfileResponse.new
      response.status = not_found
      response
    end

    let(:server_error_mvi_profile) do
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

    let(:empty_veteran_status_response) do
      response = double
      allow(response).to receive(:items).and_return([])
      allow(response).to receive(:error?).and_return(false)
      response
    end

    let(:emis_error) { EMIS::Responses::ErrorResponse.new('Failed in eMIS') }

    context 'when betamocks emis passed valid attributes' do
      before(:context) do
        Settings.vet_verification.mock_emis = false
      end

      it 'confirms veteran status for persons with a title38 status of V1' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile)
        expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status)
          .and_return(veteran_status_response)

        result = subject.get_by_attributes(valid_attributes)
        expect(result).to eq('confirmed')
      end

      it 'does not confirm for title38 status codes other than V1' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile)
        expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status)
          .and_return(non_veteran_status_response)

        result = subject.get_by_attributes(valid_attributes)
        expect(result).to eq('not confirmed')
      end

      it 'raises an exception if MVI returns a server error' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(server_error_mvi_profile)

        expect do
          subject.get_by_attributes(valid_attributes)
        end.to raise_error(MPI::Errors::ServiceError)
      end

      it 'does not confirm if a profile is not found in MVI' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(not_found_mvi_profile)

        result = subject.get_by_attributes(valid_attributes)

        expect(result).to eq('not confirmed')
      end

      it 'does not confirm if EMIS returns an error response' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile)

        expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status)
          .and_return(emis_error)

        result = subject.get_by_attributes(valid_attributes)

        expect(result).to eq('not confirmed')
      end

      it 'does not confirm if EMIS returns an empty response' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile)

        expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status)
          .and_return(empty_veteran_status_response)

        result = subject.get_by_attributes(valid_attributes)

        expect(result).to eq('not confirmed')
      end
    end

    context 'when mock-emis passed valid attributes' do
      before(:context) do
        Settings.vet_verification.mock_emis = true
        Settings.vet_verification.mock_emis_host = 'https://vaausvrsapp81.aac.va.gov'
      end

      after(:context) do
        Settings.vet_verification.mock_emis = false
      end

      it 'confirms veteran status for persons with a title38 status of V1' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile)
        expect_any_instance_of(EMIS::MockVeteranStatusService).to receive(:get_veteran_status)
          .and_return(veteran_status_response)

        result = subject.get_by_attributes(valid_attributes)
        expect(result).to eq('confirmed')
      end

      it 'does not confirm for title38 status codes other than V1' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile)
        expect_any_instance_of(EMIS::MockVeteranStatusService).to receive(:get_veteran_status)
          .and_return(non_veteran_status_response)

        result = subject.get_by_attributes(valid_attributes)
        expect(result).to eq('not confirmed')
      end

      it 'raises an exception if MVI returns a server error' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(server_error_mvi_profile)

        expect do
          subject.get_by_attributes(valid_attributes)
        end.to raise_error(MPI::Errors::ServiceError)
      end

      it 'does not confirm if a profile is not found in MVI' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(not_found_mvi_profile)

        result = subject.get_by_attributes(valid_attributes)

        expect(result).to eq('not confirmed')
      end

      it 'does not confirm if EMIS returns an error response' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile)

        expect_any_instance_of(EMIS::MockVeteranStatusService).to receive(:get_veteran_status)
          .and_return(emis_error)

        result = subject.get_by_attributes(valid_attributes)

        expect(result).to eq('not confirmed')
      end
    end
  end
end
