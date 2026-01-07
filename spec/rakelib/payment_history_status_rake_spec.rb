# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'payment_history:debug_empty rake task' do
  before(:all) do
    Rake.application.rake_require '../rakelib/payment_history_status'
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['payment_history:debug_empty'] }
  let(:icn) { '1234567890V123456' }

  before do
    task.reenable
  end

  describe 'payment_history:debug_empty' do
    context 'when no ICN is provided' do
      it 'displays usage message and exits' do
        expect { task.invoke }.to raise_error(SystemExit).and output(/Usage:/).to_stdout
      end
    end

    context 'when ICN is provided' do
      context 'and feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
        end

        it 'shows feature flag is enabled' do
          expect { task.invoke(icn) }.to output(/payment_history is ENABLED/).to_stdout
        end

        it 'masks the ICN in output' do
          expect { task.invoke(icn) }.to output(/1234\*/).to_stdout
        end
      end

      context 'and feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(false)
        end

        it 'shows feature flag is disabled' do
          expect { task.invoke(icn) }.to output(/payment_history is DISABLED/).to_stdout
        end

        it 'provides instructions to enable' do
          expect { task.invoke(icn) }.to output(/Flipper.enable/).to_stdout
        end
      end
    end

    describe 'check_user_exists' do
      let(:mpi_service) { instance_double(MPI::Service) }

      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
        allow(MPI::Service).to receive(:new).and_return(mpi_service)
      end

      context 'when user account exists and MPI profile is found' do
        let!(:user_account) { create(:user_account, icn: icn) }
        let(:mpi_profile) { build(:mpi_profile, icn: icn, given_names: ['John'], family_name: 'Doe') }
        let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows UserAccount found' do
          expect { task.invoke(icn) }.to output(/✓ UserAccount found/).to_stdout
        end

        it 'shows user verification status' do
          expect { task.invoke(icn) }.to output(/Verified: true/).to_stdout
        end

        it 'shows MPI profile found' do
          expect { task.invoke(icn) }.to output(/✓ User found in MPI/).to_stdout
        end

        it 'shows user name from MPI' do
          expect { task.invoke(icn) }.to output(/Name: John Doe/).to_stdout
        end
      end

      context 'when user account does not exist' do
        let(:mpi_profile) { build(:mpi_profile, icn: icn) }
        let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows UserAccount not found' do
          expect { task.invoke(icn) }.to output(/✗ UserAccount not found in database/).to_stdout
        end

        it 'provides helpful message' do
          expect { task.invoke(icn) }.to output(/User may not have logged in or ICN may be incorrect/).to_stdout
        end

        it 'still shows MPI profile found' do
          expect { task.invoke(icn) }.to output(/✓ User found in MPI/).to_stdout
        end
      end

      context 'when user account exists but MPI profile is not found' do
        let!(:user_account) { create(:user_account, icn: icn) }
        let(:find_profile_response) { create(:find_profile_not_found_response) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows UserAccount found' do
          expect { task.invoke(icn) }.to output(/✓ UserAccount found/).to_stdout
        end

        it 'shows MPI profile not found' do
          expect { task.invoke(icn) }.to output(/✗ User not found in MPI/).to_stdout
        end

        it 'provides helpful message about MPI' do
          expect { task.invoke(icn) }.to output(/ICN may be invalid or user may not exist in Master Person Index/).to_stdout
        end
      end

      context 'when neither user account nor MPI profile exist' do
        let(:find_profile_response) { create(:find_profile_not_found_response) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows both not found' do
          expect { task.invoke(icn) }
            .to output(/✗ UserAccount not found in database.*✗ User not found in MPI/m).to_stdout
        end
      end

      context 'when MPI service raises an error' do
        let!(:user_account) { create(:user_account, icn: icn) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .and_raise(StandardError.new('Connection timeout'))
        end

        it 'shows UserAccount found' do
          expect { task.invoke(icn) }.to output(/✓ UserAccount found/).to_stdout
        end

        it 'shows error querying MPI' do
          expect { task.invoke(icn) }.to output(/✗ Error querying MPI: Connection timeout/).to_stdout
        end
      end

      context 'when MPI returns server error response' do
        let!(:user_account) { create(:user_account, icn: icn) }
        let(:find_profile_response) { create(:find_profile_server_error_response) }

        before do
          allow(mpi_service).to receive(:find_profile_by_identifier)
            .with(identifier: icn, identifier_type: MPI::Constants::ICN)
            .and_return(find_profile_response)
        end

        it 'shows MPI lookup failed' do
          expect { task.invoke(icn) }.to output(/✗ MPI lookup failed/).to_stdout
        end
      end
    end
  end
end
