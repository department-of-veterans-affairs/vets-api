# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/debts_service'
require 'debt_management_center/models/debt_store'
require_relative 'shared_examples/debt_service_examples'

RSpec.describe DebtManagementCenter::DebtsService do
  let(:file_number) { '796043735' }
  let(:user) { build(:user, :loa3, ssn: file_number) }
  let(:user_no_ssn) { build(:user, :loa3, ssn: '') }

  # Helper to wrap VCR cassettes
  def with_vcr_cassettes(&block)
    VCR.use_cassette('bgs/people_service/person_data') do
      VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING, &block)
    end
  end

  # Helper to get all debts from service
  def all_debts(service)
    service.get_debts[:debts]
  end

  # Helper to get first composite debt ID
  def first_composite_debt_id(service)
    all_debts(service).first['compositeDebtId']
  end

  describe '#get_debts' do
    it_behaves_like 'debt service behavior'
  end

  describe '#get_debt_by_id' do
    let(:user) { build(:user, :loa3) }
    let(:debt_id) { '944147b0-7ec0-4a81-ab40-a437b5ce5353' }

    context 'when debt is missing from redis' do
      it 'raises an error' do
        with_vcr_cassettes do
          service = described_class.new(user)
          expect { service.get_debt_by_id(debt_id) }.to raise_error(described_class::DebtNotFound)
        end
      end
    end

    context 'with logged in user' do
      it 'downloads the pdf' do
        with_vcr_cassettes do
          service = described_class.new(user)
          debts = service.get_debts[:debts]
          debts.map { |d| d['id'] = SecureRandom.uuid }
          debts[0]['id'] = debt_id
          DebtManagementCenter::DebtStore.find_or_build(user.uuid).update(debts:, uuid: user.uuid)
          expect(service.get_debt_by_id(debt_id).to_json).to eq(get_fixture('dmc/debt').to_json)
        end
      end
    end
  end

  describe '#find_cdids_in_debts' do
    let(:user) { build(:user, :loa3) }
    let(:service) { described_class.new(user) }

    before do
      with_vcr_cassettes do
        service.get_debts # Load and process debts
      end
    end

    context 'with valid composite debt IDs' do
      it 'returns requested debts and empty missing_ids array' do
        composite_debt_id = first_composite_debt_id(service)
        requested_debts, missing_ids = service.send(:find_cdids_in_debts, [composite_debt_id])
        expect(requested_debts.length).to eq(1)
        expect(requested_debts.first['compositeDebtId']).to eq(composite_debt_id)
        expect(missing_ids).to be_empty
      end

      it 'returns multiple debts when multiple IDs are provided' do
        composite_debt_ids = all_debts(service).map { |d| d['compositeDebtId'] }.compact.uniq
        next unless composite_debt_ids.length >= 2

        requested_debts, missing_ids = service.send(:find_cdids_in_debts, composite_debt_ids.first(2))
        expect(requested_debts.length).to eq(2)
        expect(requested_debts.map { |d| d['compositeDebtId'] }).to match_array(composite_debt_ids.first(2))
        expect(missing_ids).to be_empty
      end
    end

    context 'when some composite debt IDs are missing' do
      it 'returns found debts and missing IDs separately' do
        composite_debt_id = first_composite_debt_id(service)
        requested_debts, missing_ids = service.send(:find_cdids_in_debts, [composite_debt_id, '999999'])
        expect(requested_debts.length).to eq(1)
        expect(requested_debts.first['compositeDebtId']).to eq(composite_debt_id)
        expect(missing_ids).to eq(['999999'])
      end
    end

    context 'with empty array' do
      it 'returns empty arrays for both debts and missing_ids' do
        requested_debts, missing_ids = service.send(:find_cdids_in_debts, [])
        expect(requested_debts).to be_empty
        expect(missing_ids).to be_empty
      end
    end

    context 'with duplicate composite debt IDs' do
      it 'returns the debt once for each duplicate ID' do
        composite_debt_id = first_composite_debt_id(service)
        requested_debts, missing_ids = service.send(:find_cdids_in_debts, [composite_debt_id, composite_debt_id])
        expect(requested_debts.length).to eq(2)
        expect(requested_debts.map { |d| d['compositeDebtId'] }).to all(eq(composite_debt_id))
        expect(missing_ids).to be_empty
      end
    end
  end

  describe '#get_debts_by_ids' do
    let(:user) { build(:user, :loa3) }
    let(:service) { described_class.new(user) }

    before do
      allow(StatsD).to receive(:increment)
    end

    context 'when debts are not yet loaded' do
      it 'loads debts automatically before lookup' do
        with_vcr_cassettes do
          composite_debt_id = first_composite_debt_id(service)
          new_service = described_class.new(user)
          expect(new_service.instance_variable_get(:@debts)).to be_nil

          result = new_service.get_debts_by_ids([composite_debt_id])

          expect(result.length).to eq(1)
          expect(new_service.instance_variable_get(:@debts)).not_to be_nil
        end
      end
    end

    context 'when some composite debt IDs are missing' do
      it 'logs warning with correct parameters' do
        with_vcr_cassettes do
          composite_debt_id = first_composite_debt_id(service)
          expect(Rails.logger).to receive(:warn).with(
            'DebtsService#get_debts_by_ids: Missing composite_debt_ids',
            hash_including(missing_composite_debt_ids: ['999999'], requested_count: 2, found_count: 1)
          )
          expect(StatsD).to receive(:increment).with(
            "#{described_class::STATSD_KEY_PREFIX}.get_debts_by_ids.missing_ids",
            tags: ['missing_count:1']
          )
          expect(StatsD).to receive(:increment).with("#{described_class::STATSD_KEY_PREFIX}.get_debt.success")

          service.get_debts_by_ids([composite_debt_id, '999999'])
        end
      end
    end

    context 'with successful lookup' do
      it 'increments success metric and does not log warning' do
        with_vcr_cassettes do
          composite_debt_id = first_composite_debt_id(service)
          expect(Rails.logger).not_to receive(:warn)
          service.get_debts_by_ids([composite_debt_id])
          expect(StatsD).not_to have_received(:increment).with(
            "#{described_class::STATSD_KEY_PREFIX}.get_debts_by_ids.missing_ids", anything
          )
          expect(StatsD).to have_received(:increment).with("#{described_class::STATSD_KEY_PREFIX}.get_debt.success")
        end
      end
    end
  end
end
