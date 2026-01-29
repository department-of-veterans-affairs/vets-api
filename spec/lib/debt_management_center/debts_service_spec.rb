# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/debts_service'
require 'debt_management_center/models/debt_store'
require_relative 'shared_examples/debt_service_examples'

RSpec.describe DebtManagementCenter::DebtsService do
  let(:file_number) { '796043735' }
  let(:user) { build(:user, :loa3, ssn: file_number) }
  let(:user_no_ssn) { build(:user, :loa3, ssn: '') }

  describe '#get_debts' do
    it_behaves_like 'debt service behavior'
  end

  describe '#get_debt_by_id' do
    let(:user) { build(:user, :loa3) }
    let(:debt_id) { '944147b0-7ec0-4a81-ab40-a437b5ce5353' }

    context 'when debt is missing from redis' do
      it 'raises an error' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
            service = described_class.new(user)
            expect { service.get_debt_by_id(debt_id) }.to raise_error do |error|
              expect(error).to be_instance_of(described_class::DebtNotFound)
            end
          end
        end
      end
    end

    context 'with logged in user' do
      it 'downloads the pdf' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
            service = described_class.new(user)
            debts = service.get_debts[:debts]
            debts.map { |d| d['id'] = SecureRandom.uuid }
            debts[0]['id'] = debt_id
            debt_store = DebtManagementCenter::DebtStore.find_or_build(user.uuid)
            debt_store.update(debts:, uuid: user.uuid)
            expect(service.get_debt_by_id(debt_id).to_json).to eq(
              get_fixture('dmc/debt').to_json
            )
          end
        end
      end
    end
  end

  describe '#find_cdids_in_debts' do
    let(:user) { build(:user, :loa3) }

    before do
      VCR.use_cassette('bgs/people_service/person_data') do
        VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
          @service = described_class.new(user)
          @service.get_debts # Load and process debts
        end
      end
    end

    context 'with valid composite debt IDs' do
      it 'returns requested debts and empty missing_ids array' do
        all_debts = @service.get_debts[:debts]
        composite_debt_id = all_debts.first['compositeDebtId']

        requested_debts, missing_ids = @service.send(:find_cdids_in_debts, [composite_debt_id])

        expect(requested_debts).to be_an(Array)
        expect(requested_debts.length).to eq(1)
        expect(requested_debts.first['compositeDebtId']).to eq(composite_debt_id)
        expect(missing_ids).to be_empty
      end

      it 'returns multiple debts when multiple IDs are provided' do
        all_debts = @service.get_debts[:debts]
        composite_debt_ids = all_debts.map { |d| d['compositeDebtId'] }.compact.uniq

        if composite_debt_ids.length >= 2
          requested_debts, missing_ids = @service.send(:find_cdids_in_debts, composite_debt_ids.first(2))

          expect(requested_debts).to be_an(Array)
          expect(requested_debts.length).to eq(2)
          expect(requested_debts.map { |d| d['compositeDebtId'] }).to match_array(composite_debt_ids.first(2))
          expect(missing_ids).to be_empty
        end
      end
    end

    context 'when some composite debt IDs are missing' do
      it 'returns found debts and missing IDs separately' do
        all_debts = @service.get_debts[:debts]
        valid_id = all_debts.first['compositeDebtId']
        invalid_id = '999999'

        requested_debts, missing_ids = @service.send(:find_cdids_in_debts, [valid_id, invalid_id])

        expect(requested_debts).to be_an(Array)
        expect(requested_debts.length).to eq(1)
        expect(requested_debts.first['compositeDebtId']).to eq(valid_id)
        expect(missing_ids).to eq([invalid_id])
      end
    end

    context 'with empty array' do
      it 'returns empty arrays for both debts and missing_ids' do
        requested_debts, missing_ids = @service.send(:find_cdids_in_debts, [])

        expect(requested_debts).to be_an(Array)
        expect(requested_debts).to be_empty
        expect(missing_ids).to be_an(Array)
        expect(missing_ids).to be_empty
      end
    end

    context 'with duplicate composite debt IDs' do
      it 'returns the debt once for each duplicate ID' do
        all_debts = @service.get_debts[:debts]
        composite_debt_id = all_debts.first['compositeDebtId']

        requested_debts, missing_ids = @service.send(:find_cdids_in_debts, [composite_debt_id, composite_debt_id])

        expect(requested_debts.length).to eq(2)
        expect(requested_debts.map { |d| d['compositeDebtId'] }).to all(eq(composite_debt_id))
        expect(missing_ids).to be_empty
      end
    end
  end

  describe '#get_debts_by_ids' do
    let(:user) { build(:user, :loa3) }

    before do
      allow(StatsD).to receive(:increment)
    end

    context 'when debts are not yet loaded' do
      it 'loads debts automatically before lookup' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
            service = described_class.new(user)
            all_debts = service.get_debts[:debts]
            composite_debt_id = all_debts.first['compositeDebtId']

            # Create a new service instance to ensure debts aren't loaded
            new_service = described_class.new(user)
            expect(new_service.instance_variable_get(:@debts)).to be_nil

            result = new_service.get_debts_by_ids([composite_debt_id])

            expect(result).to be_an(Array)
            expect(result.length).to eq(1)
            expect(new_service.instance_variable_get(:@debts)).not_to be_nil
          end
        end
      end
    end

    context 'when some composite debt IDs are missing' do
      it 'logs warning with correct parameters' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
            service = described_class.new(user)
            all_debts = service.get_debts[:debts]
            valid_id = all_debts.first['compositeDebtId']
            invalid_id = '999999'

            expect(Rails.logger).to receive(:warn).with(
              'DebtsService#get_debts_by_ids: Missing composite_debt_ids',
              hash_including(
                user_uuid: user.uuid,
                missing_composite_debt_ids: [invalid_id],
                requested_count: 2,
                found_count: 1
              )
            )
            expect(StatsD).to receive(:increment).with(
              "#{described_class::STATSD_KEY_PREFIX}.get_debts_by_ids.missing_ids",
              tags: ['missing_count:1']
            )
            expect(StatsD).to receive(:increment).with("#{described_class::STATSD_KEY_PREFIX}.get_debt.success")

            service.get_debts_by_ids([valid_id, invalid_id])
          end
        end
      end
    end

    context 'with successful lookup' do
      it 'increments success metric' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
            service = described_class.new(user)
            all_debts = service.get_debts[:debts]
            composite_debt_id = all_debts.first['compositeDebtId']

            expect(Rails.logger).not_to receive(:warn)

            service.get_debts_by_ids([composite_debt_id])

            expect(StatsD).not_to have_received(:increment).with(
              "#{described_class::STATSD_KEY_PREFIX}.get_debts_by_ids.missing_ids",
              anything
            )
            expect(StatsD).to have_received(:increment).with("#{described_class::STATSD_KEY_PREFIX}.get_debt.success")
          end
        end
      end
    end
  end
end
