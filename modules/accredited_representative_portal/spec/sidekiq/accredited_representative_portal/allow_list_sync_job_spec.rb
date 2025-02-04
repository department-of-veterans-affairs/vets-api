# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module AccreditedRepresentativePortal
  RSpec.describe AllowListSyncJob, type: :job do
    let(:csv_content) do
      <<~CSV
        accredited_individual_registration_number,power_of_attorney_holder_type,user_account_email
        REG001,veteran_service_organization,rep1@vso.org
        REG002,veteran_service_organization,rep2@vso.org
      CSV
    end

    let(:github_client) do
      instance_double(
        Octokit::Client,
        contents: double('GithubResponse', content: Base64.encode64(csv_content))
      )
    end

    before do
      allow(Octokit::Client).to receive(:new).and_return(github_client)
    end

    describe 'constants' do
      it 'defines max rows limit' do
        expect(described_class::MAX_CSV_ROWS).to eq(500)
      end

      it 'defines sync fields' do
        expect(described_class::SYNC_FIELDS).to contain_exactly(
          'accredited_individual_registration_number',
          'power_of_attorney_holder_type',
          'user_account_email'
        )
      end
    end

    describe '#perform' do
      context 'with valid data' do
        before do
          # This record should be deleted since it's not in the incoming CSV
          UserAccountAccreditedIndividual.create!(
            accredited_individual_registration_number: 'OLD001',
            power_of_attorney_holder_type: 'veteran_service_organization',
            user_account_email: 'old@vso.org'
          )
        end

        it 'processes CSV from GitHub and syncs records' do
          expect(Rails.logger).to receive(:info).with(/Fetching CSV from GitHub/)
          expect(Rails.logger).to receive(:info).with(/Successfully synced/)

          described_class.new.perform

          records = UserAccountAccreditedIndividual.all
          expect(records.count).to eq(2)

          expect(records.pluck(:accredited_individual_registration_number))
            .to match_array(%w[REG001 REG002])

          # Verify old record was deleted
          expect(UserAccountAccreditedIndividual.where(
                   accredited_individual_registration_number: 'OLD001'
                 )).not_to exist
        end
      end

      context 'when CSV is empty' do
        let(:csv_content) { '' }

        it 'logs error and re-raises' do
          expect(Rails.logger).to receive(:error).with(/Empty CSV data received/)
          expect { described_class.new.perform }
            .to raise_error(described_class::InvalidRowCount)
        end
      end

      context 'when CSV exceeds size limit' do
        let(:csv_content) do
          headers = "accredited_individual_registration_number,power_of_attorney_holder_type,user_account_email\n"
          rows = (['REG001,veteran_service_organization,rep@vso.org'] * 501).join("\n")
          headers + rows
        end

        it 'raises InvalidRowCount' do
          expect { described_class.new.perform }
            .to raise_error(described_class::InvalidRowCount)
        end
      end

      context 'with invalid data in CSV' do
        let(:csv_content) do
          <<~CSV
            accredited_individual_registration_number,power_of_attorney_holder_type,user_account_email
            REG001,veteran_service_organization,not-an-email
          CSV
        end

        it 'raises validation error and rolls back' do
          expect { described_class.new.perform }
            .to raise_error(ActiveRecord::RecordInvalid)

          expect(UserAccountAccreditedIndividual.count).to eq(0)
        end
      end

      context 'with GitHub API error' do
        before do
          allow(github_client).to receive(:contents).and_raise(Octokit::Error.new)
        end

        it 'logs and re-raises error' do
          expect(Rails.logger).to receive(:error).with(/Error syncing accredited individuals/)
          expect { described_class.new.perform }.to raise_error(Octokit::Error)
        end
      end

      context 'with CSV parsing error' do
        let(:csv_content) do
          <<~CSV
            accredited_individual_registration_number,power_of_attorney_holder_type,user_account_email
            "
          CSV
        end

        it 'logs and re-raises error' do
          expect(Rails.logger).to receive(:error).with(/Error syncing accredited individuals/)
          expect { described_class.new.perform }.to raise_error(CSV::MalformedCSVError)
        end
      end
    end

    # rubocop:disable RSpec/MessageChain
    describe 'GitHub configuration' do
      it 'uses settings for GitHub configuration' do
        job = described_class.new

        allow(Settings).to receive_message_chain(
          'accredited_representative_portal.allow_list.github.access_token'
        ).and_return('test-token')

        expect(Octokit::Client).to receive(:new).with(access_token: 'test-token')

        job.send(:github_client)
      end
    end
    # rubocop:enable RSpec/MessageChain
  end
end
# rubocop:enable Metrics/ModuleLength
