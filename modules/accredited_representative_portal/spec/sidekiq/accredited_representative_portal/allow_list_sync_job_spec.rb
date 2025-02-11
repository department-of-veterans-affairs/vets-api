# frozen_string_literal: true

require 'rails_helper'
require Rails.root / 'modules/accredited_representative_portal/spec/rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe AllowListSyncJob, type: :job do
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

      before do
        allow_any_instance_of(described_class).to receive(:extract).and_return(csv_content)
      end

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
            described_class.new.perform

            records = UserAccountAccreditedIndividual.all
            expect(records.count).to eq(2)
            expect(records.pluck(:accredited_individual_registration_number))
              .to match_array(%w[REG001 REG002])
          end
        end

        context 'with invalid power_of_attorney_holder_type' do
          let(:csv_content) do
            data = <<~CSV
              accredited_individual_registration_number,power_of_attorney_holder_type,user_account_email
              REG001,attorney,rep1@vso.org
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

          it 'logs error and raises RecordCountError' do
            expect { described_class.new.perform }
              .to raise_error(described_class::RecordCountError, /record_count: 0/)
          end
        end

        context 'when CSV has too many rows' do
          let(:csv_content) do
            headers = 'accredited_individual_registration_number,power_of_attorney_holder_type,user_account_email'
            rows = (1..501).map do |i|
              "REG#{i.to_s.rjust(3, '0')},veteran_service_organization,rep#{i}@vso.org"
            end

            CSV.parse(([headers] + rows).join("\n"), headers: true)
          end

          it 'logs error and raises RecordCountError' do
            expect { described_class.new.perform }
              .to raise_error(described_class::RecordCountError, /record_count: 501/)
          end
        end
      end
    end
  end
end
