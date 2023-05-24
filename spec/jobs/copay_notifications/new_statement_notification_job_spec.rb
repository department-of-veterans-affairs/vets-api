# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CopayNotifications::NewStatementNotificationJob, type: :worker do
  before do
    Sidekiq::Worker.clear_all
  end

  describe '#perform' do
    let(:mpi_profile) { build(:mpi_profile) }
    let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }
    let(:profile_response_error) { create(:find_profile_server_error_response) }
    let(:profile_not_found_error) { create(:find_profile_not_found_response) }
    let(:statement) do
      {
        'veteranIdentifier' => '492031291',
        'identifierType' => 'edipi',
        'facilityNum' => '123',
        'facilityName' => 'VA Medical Center',
        'statementDate' => '01/01/2023'
      }
    end

    before do
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_response)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_facility).and_return(profile_response)
    end

    it 'sends a new mcp notification email job frome edipi' do
      job = described_class.new
      expect { job.perform(statement) }
        .to change { CopayNotifications::McpNotificationEmailJob.jobs.size }
        .from(0)
        .to(1)
    end

    context 'veteran identifier is a vista id' do
      let(:statement) do
        {
          'veteranIdentifier' => '348530923',
          'identifierType' => 'dfn',
          'facilityNum' => '456',
          'facilityName' => 'VA Medical Center',
          'statementDate' => '01/01/2023'
        }
      end

      it 'sends a new mcp notification email job frome facility and vista id' do
        job = described_class.new
        expect { job.perform(statement) }
          .to change { CopayNotifications::McpNotificationEmailJob.jobs.size }
          .from(0)
          .to(1)
      end
    end

    context 'MPI profile not found' do
      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_not_found_error)
      end

      it 'raises not found error from MPI' do
        job = described_class.new
        expect { job.perform(statement) }
          .to raise_error(MPI::Errors::RecordNotFound)
      end
    end

    context 'MPI service error' do
      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_response_error)
      end

      it 'raises server error from MPI' do
        job = described_class.new
        expect { job.perform(statement) }
          .to raise_error(MPI::Errors::FailedRequestError)
      end
    end

    context 'MPI profile does not contain vet360 id' do
      let(:mpi_profile) { build(:mpi_profile, vet360_id: nil) }

      it 'raises vet360 id not found error' do
        job = described_class.new
        expect(job).to receive(:log_exception_to_sentry).with(
          instance_of(CopayNotifications::Vet360IdNotFound), {}, { error: :new_statement_notification_job_error }
        )
        job.perform(statement)
      end
    end
  end
end
