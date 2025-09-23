# frozen_string_literal: true

require 'rails_helper'
require Rails.root / 'modules/accredited_representative_portal/spec/rails_helper'
require 'base64'

RSpec.describe AccreditedRepresentativePortal::AllowListSyncJob, type: :job do
  def build_csv(rows)
    headers = 'accredited_individual_registration_number,power_of_attorney_holder_type,user_account_email'
    CSV.parse(([headers] + rows).join("\n"), headers: true)
  end

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
      data = <<~CSV
        accredited_individual_registration_number,power_of_attorney_holder_type,user_account_email
        REG001,veteran_service_organization,rep1@vso.org
        REG002,veteran_service_organization,rep2@vso.org
      CSV

      CSV.parse(data, headers: true)
    end

    let(:record_class) { AccreditedRepresentativePortal::UserAccountAccreditedIndividual }

    before do
      allow_any_instance_of(described_class).to receive(:extract).and_return(csv_content)
    end

    describe '#perform' do
      context 'with valid data' do
        let(:logger) { instance_double(SemanticLogger::Logger, info: true, error: true) }

        before do
          # Create an existing record that should be deleted
          record_class.create!(
            accredited_individual_registration_number: 'OLD001',
            power_of_attorney_holder_type: 'veteran_service_organization',
            user_account_email: 'old@vso.org'
          )
          allow_any_instance_of(described_class).to receive(:logger).and_return(logger)
        end

        it 'processes CSV from GitHub and syncs records' do
          described_class.new.perform

          records = record_class.all
          expect(records.count).to eq(2)
          expect(records.pluck(:accredited_individual_registration_number))
            .to match_array(%w[REG001 REG002])
        end

        it 'logs the result via logger.info' do
          expect_any_instance_of(described_class)
            .to receive(:load)
            .and_wrap_original do |m, *args|
              result = m.call(*args)
              expect(result).to include(:deleted_count, :inserted_count)
              result
            end

          described_class.new.perform

          expect(logger).to have_received(:info).with(hash_including(:deleted_count, :inserted_count))
        end
      end

      context 'with invalid power_of_attorney_holder_type' do
        let(:csv_content) do
          data = <<~CSV
            accredited_individual_registration_number,power_of_attorney_holder_type,user_account_email
            REG001,not_a_real_type,rep1@vso.org
            REG002,veteran_service_organization,rep2@vso.org
          CSV

          CSV.parse(data, headers: true)
        end

        it 'raises an ActiveRecord::RecordInvalid error' do
          expect do
            described_class.new.perform
          end.to raise_error(ActiveRecord::RecordInvalid, /Power of attorney holder type is not included in the list/)
        end
      end

      context 'with invalid email format' do
        let(:csv_content) do
          data = <<~CSV
            accredited_individual_registration_number,power_of_attorney_holder_type,user_account_email
            REG001,veteran_service_organization,not-an-email
            REG002,veteran_service_organization,rep2@vso.org
          CSV

          CSV.parse(data, headers: true)
        end

        it 'raises an ActiveRecord::RecordInvalid error' do
          expect do
            described_class.new.perform
          end.to raise_error(ActiveRecord::RecordInvalid, /Validation failed: User account email is invalid/)
        end
      end

      context 'when CSV is empty' do
        let(:csv_content) { CSV.parse('', headers: true) }

        it 'raises RecordCountError' do
          expect { described_class.new.perform }
            .to raise_error(described_class::RecordCountError, /record_count: 0/)
        end
      end

      context 'when CSV has too many rows' do
        let(:csv_content) do
          rows = (1..501).map do |i|
            format('REG%<n>03d,veteran_service_organization,rep%<i>d@vso.org', n: i, i:)
          end

          build_csv(rows)
        end

        it 'raises RecordCountError' do
          expect { described_class.new.perform }
            .to raise_error(described_class::RecordCountError, /record_count: 501/)
        end
      end

      context 'when CSV is exactly at MAX_RECORD_COUNT boundary (500)' do
        let(:csv_content) do
          rows = (1..described_class::MAX_RECORD_COUNT).map do |i|
            format('REG%<n>03d,veteran_service_organization,rep%<i>d@vso.org', n: i, i:)
          end
          build_csv(rows)
        end

        it 'succeeds and inserts all rows' do
          expect { described_class.new.perform }.to change(record_class, :count).by(500)
        end
      end

      context 'when an unexpected error occurs during extract/transform/load' do
        it 'logs the error then re-raises' do
          job = described_class.new
          allow(job).to receive(:load).and_raise(StandardError, 'boom')

          logger = instance_double(SemanticLogger::Logger, info: true, error: true)
          allow(job).to receive(:logger).and_return(logger)

          expect { job.perform }.to raise_error(StandardError, 'boom')
          expect(logger).to have_received(:error).with(instance_of(StandardError))
        end
      end
    end
  end

  describe '#extract (unit)' do
    let(:fake_settings) do
      OpenStruct.new(
        accredited_representative_portal: OpenStruct.new(
          allow_list: OpenStruct.new(
            github: OpenStruct.new(
              base_uri: 'https://api.github.example/',
              access_token: 'token',
              repo: 'org/repo',
              path: 'dir/allow_list.csv'
            )
          )
        )
      )
    end

    let(:csv_string) do
      <<~CSV
        accredited_individual_registration_number,power_of_attorney_holder_type,user_account_email
        REG777,veteran_service_organization,rep777@vso.org
      CSV
    end

    it 'returns a parsed CSV with headers from GitHub contents' do
      stub_const('Settings', fake_settings)

      client = instance_double(Octokit::Client)
      expect(Octokit::Client).to receive(:new).with(
        api_endpoint: 'https://api.github.example/',
        access_token: 'token'
      ).and_return(client)

      encoded = Base64.strict_encode64(csv_string)
      expect(client).to receive(:contents).with('org/repo', path: 'dir/allow_list.csv')
                                          .and_return({ content: encoded })

      csv = described_class.new.send(:extract)

      expect(csv).to be_a(CSV::Table)
      expect(csv.headers).to include(
        'accredited_individual_registration_number',
        'power_of_attorney_holder_type',
        'user_account_email'
      )
      expect(csv.size).to eq(1)
      expect(csv.first['accredited_individual_registration_number']).to eq('REG777')
    end
  end
end
