# frozen_string_literal: true

require 'rails_helper'
require Rails.root / 'modules/accredited_representative_portal/spec/rails_helper'

RSpec.describe AccreditedRepresentativePortal::AllowListSyncJob, type: :job do
  context 'vcr tests' do
    it 'makes insertions and deletions when source changes' do
      use_cassette('insertions_and_deletions', match_requests_on: %i[method uri]) do
        record_class = AccreditedRepresentativePortal::UserAccountAccreditedIndividual

        described_class.new.perform
        record_class.find_each { |record| record.update!(user_account_icn: SecureRandom.uuid) }
        before = record_class.all.to_a

        described_class.new.perform
        after = record_class.all.to_a

        expect((before - after).size).to be(4)
        expect((after - before).size).to be(4)

        maintained_icns = record_class.where.not(user_account_icn: nil)
        expect(maintained_icns.count).to be(16)
      end
    end
  end

  context 'client mock tests' do
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

    # rubocop:disable RSpec/MessageChain
    before do
      allow(Octokit::Client).to receive(:new).and_return(github_client)
      # Stub GitHub settings
      allow(Settings).to receive_message_chain(
        'accredited_representative_portal.allow_list.github.access_token'
      ).and_return('test-token')
      allow(Settings).to receive_message_chain(
        'accredited_representative_portal.allow_list.github.repo'
      ).and_return('test-repo')
      allow(Settings).to receive_message_chain(
        'accredited_representative_portal.allow_list.github.path'
      ).and_return('test/path.csv')
    end
    # rubocop:enable RSpec/MessageChain

    describe '#perform' do
      context 'with valid data' do
        before do
          # Create an existing record that should be deleted
          UserAccountAccreditedIndividual.create!(
            accredited_individual_registration_number: 'OLD001',
            power_of_attorney_holder_type: 'veteran_service_organization',
            user_account_email: 'old@vso.org'
          )
        end

        it 'processes CSV from GitHub and syncs records' do
          expect(Rails.logger).to receive(:info).with('Fetching CSV from GitHub: test-repo path: test/path.csv')
          expect(Rails.logger).to receive(:info)
            .with('Successfully synced accredited individuals. Replaced 1 records with 2 records.')

          described_class.new.perform

          records = UserAccountAccreditedIndividual.all
          expect(records.count).to eq(2)
          expect(records.pluck(:accredited_individual_registration_number))
            .to match_array(%w[REG001 REG002])
        end
      end

      context 'with invalid power_of_attorney_holder_type' do
        let(:csv_content) do
          <<~CSV
            accredited_individual_registration_number,power_of_attorney_holder_type,user_account_email
            REG001,attorney,rep1@vso.org
            REG002,veteran_service_organization,rep2@vso.org
          CSV
        end

        it 'skips invalid records and processes valid ones' do
          expect(Rails.logger).to receive(:info).with('Fetching CSV from GitHub: test-repo path: test/path.csv')
          expect(Rails.logger).to receive(:info)
            .with('Successfully synced accredited individuals. Replaced 0 records with 1 records.')

          described_class.new.perform

          expect(UserAccountAccreditedIndividual.count).to eq(1)
          record = UserAccountAccreditedIndividual.first
          expect(record.power_of_attorney_holder_type).to eq('veteran_service_organization')
          expect(record.accredited_individual_registration_number).to eq('REG002')
        end
      end

      context 'with invalid email format' do
        let(:csv_content) do
          <<~CSV
            accredited_individual_registration_number,power_of_attorney_holder_type,user_account_email
            REG001,veteran_service_organization,not-an-email
            REG002,veteran_service_organization,rep2@vso.org
          CSV
        end

        it 'processes valid records and logs stats' do
          expect(Rails.logger).to receive(:info).with('Fetching CSV from GitHub: test-repo path: test/path.csv')
          expect(Rails.logger).to receive(:info)
            .with('Successfully synced accredited individuals. Replaced 0 records with 1 records.')

          described_class.new.perform

          expect(UserAccountAccreditedIndividual.count).to eq(1)
          expect(UserAccountAccreditedIndividual.first.user_account_email).to eq('rep2@vso.org')
        end
      end

      context 'when CSV is empty' do
        let(:csv_content) { '' }

        it 'logs error and raises InvalidRowCount' do
          expect(Rails.logger).to receive(:error).with(/Error syncing accredited individuals.*Empty CSV data received/)
          expect { described_class.new.perform }
            .to raise_error(described_class::InvalidRowCount, /Empty CSV data received/)
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
    end
  end
end
