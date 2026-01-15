# frozen_string_literal: true

require 'rails_helper'
require 'mhv/oh_facilities_helper/service'

RSpec.describe MHV::OhFacilitiesHelper::Service do
  subject(:service) { described_class.new(user) }

  let(:user) { build(:user) }
  let(:va_treatment_facility_ids) { %w[516 553] }
  let(:pretransitioned_oh_facilities) { '516, 517, 518' }
  let(:facilities_ready_for_info_alert) { '553, 554' }
  let(:facilities_migrating_to_oh) { '554' }

  before do
    allow(user).to receive(:va_treatment_facility_ids).and_return(va_treatment_facility_ids)
    allow(Settings.mhv.oh_facility_checks).to receive_messages(
      pretransitioned_oh_facilities:,
      facilities_ready_for_info_alert:,
      facilities_migrating_to_oh:
    )
  end

  describe '#user_at_pretransitioned_oh_facility?' do
    context 'when user has a facility in pretransitioned OH facilities list' do
      let(:va_treatment_facility_ids) { %w[516 999] }

      it 'returns true' do
        expect(service.user_at_pretransitioned_oh_facility?).to be true
      end
    end

    context 'when user has no facilities in pretransitioned OH facilities list' do
      let(:va_treatment_facility_ids) { %w[999 888] }

      it 'returns false' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when user has nil va_treatment_facility_ids' do
      let(:va_treatment_facility_ids) { nil }

      it 'returns false' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when user has empty va_treatment_facility_ids' do
      let(:va_treatment_facility_ids) { [] }

      it 'returns false' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when facility id is numeric and matches string in settings' do
      let(:va_treatment_facility_ids) { [516, 999] }

      it 'returns true' do
        expect(service.user_at_pretransitioned_oh_facility?).to be true
      end
    end
  end

  describe '#user_facility_ready_for_info_alert?' do
    context 'when user has a facility in facilities ready for info alert list' do
      let(:va_treatment_facility_ids) { %w[553 999] }

      it 'returns true when user is behind feature toggle' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_labs_and_tests_enabled,
                                                  user).and_return(true)
        expect(service.user_facility_ready_for_info_alert?).to be true
      end

      it 'returns false when user is not behind feature toggle' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(false)
        expect(service.user_facility_ready_for_info_alert?).to be false
      end

      it 'returns false when power switch is disabled, even if others are enabled' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_labs_and_tests_enabled,
                                                  user).and_return(true)
        expect(service.user_facility_ready_for_info_alert?).to be false
      end

      it 'returns false when power switch is enabled, but all others disabled' do
        oh_feature_toggles = MHV::OhFacilitiesHelper::Service::OH_FEATURE_TOGGLES

        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(true)
        oh_feature_toggles.each do |toggle|
          allow(Flipper).to receive(:enabled?).with(toggle, user).and_return(false)
        end
        expect(service.user_facility_ready_for_info_alert?).to be false
      end
    end

    context 'when user has no facilities in facilities ready for info alert list' do
      let(:va_treatment_facility_ids) { %w[999 888] }

      it 'returns false' do
        expect(service.user_facility_ready_for_info_alert?).to be false
      end
    end

    context 'when user has nil va_treatment_facility_ids' do
      let(:va_treatment_facility_ids) { nil }

      it 'returns false' do
        expect(service.user_facility_ready_for_info_alert?).to be false
      end
    end

    context 'when user has empty va_treatment_facility_ids' do
      let(:va_treatment_facility_ids) { [] }

      it 'returns false' do
        expect(service.user_facility_ready_for_info_alert?).to be false
      end
    end

    context 'when facility id is numeric and matches string in settings' do
      let(:va_treatment_facility_ids) { [553, 999] }

      it 'returns true when user is behind feature toggles' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_labs_and_tests_enabled,
                                                  user).and_return(true)

        expect(service.user_facility_ready_for_info_alert?).to be true
      end

      it 'returns false when user is not behind feature toggles' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(false)

        expect(service.user_facility_ready_for_info_alert?).to be false
      end
    end
  end

  describe '#user_facility_migrating_to_oh?' do
    context 'when user has a facility in migrating OH facilities list' do
      let(:va_treatment_facility_ids) { %w[516 554] }

      it 'returns true' do
        expect(service.user_facility_migrating_to_oh?).to be true
      end
    end

    context 'when user has no facilities in migrating OH facilities list' do
      let(:va_treatment_facility_ids) { %w[999 888] }

      it 'returns false' do
        expect(service.user_facility_migrating_to_oh?).to be false
      end
    end

    context 'when user has nil va_treatment_facility_ids' do
      let(:va_treatment_facility_ids) { nil }

      it 'returns false' do
        expect(service.user_facility_migrating_to_oh?).to be false
      end
    end

    context 'when user has empty va_treatment_facility_ids' do
      let(:va_treatment_facility_ids) { [] }

      it 'returns false' do
        expect(service.user_facility_migrating_to_oh?).to be false
      end
    end

    context 'when facility id is numeric and matches string in settings' do
      let(:va_treatment_facility_ids) { [516, 554] }

      it 'returns true' do
        expect(service.user_facility_migrating_to_oh?).to be true
      end
    end
  end

  describe 'Settings edge cases' do
    let(:va_treatment_facility_ids) { %w[516] }

    context 'when Settings value is nil' do
      let(:pretransitioned_oh_facilities) { nil }

      it 'returns false for user_at_pretransitioned_oh_facility?' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when Settings value is false' do
      let(:pretransitioned_oh_facilities) { false }

      it 'returns false for user_at_pretransitioned_oh_facility?' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when Settings value is 0' do
      let(:pretransitioned_oh_facilities) { 0 }

      it 'returns false for user_at_pretransitioned_oh_facility?' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when Settings value is an empty string' do
      let(:pretransitioned_oh_facilities) { '' }

      it 'returns false for user_at_pretransitioned_oh_facility?' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when Settings value is a number (interpreted as facility ID)' do
      let(:pretransitioned_oh_facilities) { 516 }
      let(:va_treatment_facility_ids) { %w[516] }

      it 'returns true when user facility matches' do
        expect(service.user_at_pretransitioned_oh_facility?).to be true
      end
    end

    context 'when Settings value has extra whitespace' do
      let(:pretransitioned_oh_facilities) { '  516  ,  517  ,  518  ' }

      it 'strips whitespace and matches correctly' do
        expect(service.user_at_pretransitioned_oh_facility?).to be true
      end
    end

    context 'when Settings value has trailing comma' do
      let(:pretransitioned_oh_facilities) { '516,517,' }

      it 'handles trailing comma and matches correctly' do
        expect(service.user_at_pretransitioned_oh_facility?).to be true
      end
    end
  end

  describe '#get_oh_migration_info' do
    let(:user) { build(:user, :loa3) }
    let(:user_facility_ids) { %w[516 517] }
    let(:service) { described_class.new(user) }
    let(:oh_migrations_list) { nil }

    before do
      allow(user).to receive(:va_treatment_facility_ids).and_return(user_facility_ids)
      allow(Settings.mhv.oh_facility_checks).to receive(:oh_migrations_list).and_return(oh_migrations_list)
    end

    context 'Configuration' do
      it 'reads oh_migrations_list from Settings.mhv.oh_facility_checks' do
        expect(Settings.mhv.oh_facility_checks).to receive(:oh_migrations_list)
        service.get_oh_migration_info
      end
    end

    context 'Method Interface' do
      it 'is a public method' do
        expect(service).to respond_to(:get_oh_migration_info)
      end

      it 'returns an Array' do
        expect(service.get_oh_migration_info).to be_an(Array)
      end
    end

    context 'Parsing' do
      context 'when oh_migrations_list is nil' do
        let(:oh_migrations_list) { nil }

        it 'returns an empty array' do
          expect(service.get_oh_migration_info).to eq([])
        end
      end

      context 'when oh_migrations_list is empty string' do
        let(:oh_migrations_list) { '' }

        it 'returns an empty array' do
          expect(service.get_oh_migration_info).to eq([])
        end
      end

      context 'when oh_migrations_list is whitespace only' do
        let(:oh_migrations_list) { '   ' }

        it 'returns an empty array' do
          expect(service.get_oh_migration_info).to eq([])
        end
      end

      context 'when oh_migrations_list has valid format' do
        let(:user_facility_ids) { %w[516] }
        let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA Medical Center]' }

        it 'parses the migration entry correctly' do
          result = service.get_oh_migration_info
          expect(result.length).to eq(1)
          expect(result.first[:migration_date]).to eq('March 3, 2026')
        end
      end

      context 'when oh_migrations_list has multiple entries separated by semicolons' do
        let(:user_facility_ids) { %w[516 517 518] }
        let(:oh_migrations_list) do
          '2026-03-03:[516,Columbus VA];2026-04-01:[517,Toledo VA];2026-05-01:[518,Cleveland VA]'
        end

        it 'parses all entries' do
          result = service.get_oh_migration_info
          expect(result.length).to eq(3)
        end
      end
    end

    context 'Facility Extraction' do
      context 'when user has matching facilities' do
        let(:user_facility_ids) { %w[516 517] }
        let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA],[517,Toledo VA],[999,Other VA]' }

        it 'only includes facilities matching user va_treatment_facility_ids' do
          result = service.get_oh_migration_info
          expect(result.length).to eq(1)
          facility_ids = result.first[:facilities].map { |f| f[:id] }
          expect(facility_ids).to contain_exactly('516', '517')
        end
      end

      context 'when user has no matching facilities' do
        let(:user_facility_ids) { %w[999 888] }
        let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }

        it 'returns an empty array' do
          expect(service.get_oh_migration_info).to eq([])
        end
      end

      context 'when user has empty facility list' do
        let(:user_facility_ids) { [] }
        let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }

        it 'returns an empty array' do
          expect(service.get_oh_migration_info).to eq([])
        end
      end
    end

    context 'Facility Merging' do
      let(:user_facility_ids) { %w[516 517] }

      context 'when multiple facilities share the same migration date' do
        let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA],[517,Toledo VA]' }

        it 'merges them into a single entry' do
          result = service.get_oh_migration_info
          expect(result.length).to eq(1)
          expect(result.first[:facilities].length).to eq(2)
        end
      end

      context 'when facilities have different migration dates' do
        let(:user_facility_ids) { %w[516 517] }
        let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA];2026-04-01:[517,Toledo VA]' }

        it 'returns separate entries' do
          result = service.get_oh_migration_info
          expect(result.length).to eq(2)
        end
      end
    end

    context 'Phase Dates' do
      let(:user_facility_ids) { %w[516] }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }
      let(:migration_date) { Date.new(2026, 3, 3) }

      it 'includes all 8 phases (p0 through p7)' do
        result = service.get_oh_migration_info
        phases = result.first[:phases]
        expect(phases.keys).to include(:p0, :p1, :p2, :p3, :p4, :p5, :p6, :p7)
      end

      it 'calculates p0 as migration date minus 60 days' do
        result = service.get_oh_migration_info
        expected_date = (migration_date - 60).strftime('%B %-d, %Y')
        expect(result.first[:phases][:p0]).to eq(expected_date)
      end

      it 'calculates p1 as migration date minus 45 days' do
        result = service.get_oh_migration_info
        expected_date = (migration_date - 45).strftime('%B %-d, %Y')
        expect(result.first[:phases][:p1]).to eq(expected_date)
      end

      it 'calculates p2 as migration date minus 30 days' do
        result = service.get_oh_migration_info
        expected_date = (migration_date - 30).strftime('%B %-d, %Y')
        expect(result.first[:phases][:p2]).to eq(expected_date)
      end

      it 'calculates p3 as migration date minus 5 days' do
        result = service.get_oh_migration_info
        expected_date = (migration_date - 5).strftime('%B %-d, %Y')
        expect(result.first[:phases][:p3]).to eq(expected_date)
      end

      it 'calculates p4 as migration date minus 2 days' do
        result = service.get_oh_migration_info
        expected_date = (migration_date - 2).strftime('%B %-d, %Y')
        expect(result.first[:phases][:p4]).to eq(expected_date)
      end

      it 'calculates p5 as migration date (day 0)' do
        result = service.get_oh_migration_info
        expected_date = migration_date.strftime('%B %-d, %Y')
        expect(result.first[:phases][:p5]).to eq(expected_date)
      end

      it 'calculates p6 as migration date plus 2 days' do
        result = service.get_oh_migration_info
        expected_date = (migration_date + 2).strftime('%B %-d, %Y')
        expect(result.first[:phases][:p6]).to eq(expected_date)
      end

      it 'calculates p7 as migration date plus 7 days' do
        result = service.get_oh_migration_info
        expected_date = (migration_date + 7).strftime('%B %-d, %Y')
        expect(result.first[:phases][:p7]).to eq(expected_date)
      end
    end

    context 'Date Formatting' do
      let(:user_facility_ids) { %w[516] }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }

      it 'formats migration_date as human-readable string' do
        result = service.get_oh_migration_info
        expect(result.first[:migration_date]).to eq('March 3, 2026')
      end

      it 'formats phase dates as human-readable strings' do
        result = service.get_oh_migration_info
        # Check p5 (the migration date itself)
        expect(result.first[:phases][:p5]).to eq('March 3, 2026')
      end

      context 'with single-digit day' do
        let(:oh_migrations_list) { '2026-01-05:[516,Columbus VA]' }

        it 'formats without leading zero on day' do
          result = service.get_oh_migration_info
          expect(result.first[:migration_date]).to eq('January 5, 2026')
        end
      end
    end

    context 'Phase Boundaries (Inclusive)' do
      let(:user_facility_ids) { %w[516] }
      let(:migration_date) { Date.new(2026, 3, 3) }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }

      context 'when today is exactly at phase boundary' do
        it 'day -60 is start of p0 (in p0)' do
          allow(Time.zone).to receive(:today).and_return(migration_date - 60)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to eq('p0')
        end

        it 'day -45 is start of p1 (in p1)' do
          allow(Time.zone).to receive(:today).and_return(migration_date - 45)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to eq('p1')
        end

        it 'day -30 is start of p2 (in p2)' do
          allow(Time.zone).to receive(:today).and_return(migration_date - 30)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to eq('p2')
        end

        it 'day -5 is start of p3 (in p3)' do
          allow(Time.zone).to receive(:today).and_return(migration_date - 5)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to eq('p3')
        end

        it 'day -2 is start of p4 (in p4)' do
          allow(Time.zone).to receive(:today).and_return(migration_date - 2)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to eq('p4')
        end

        it 'day 0 is start of p5 (in p5)' do
          allow(Time.zone).to receive(:today).and_return(migration_date)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to eq('p5')
        end

        it 'day +2 is start of p6 (in p6)' do
          allow(Time.zone).to receive(:today).and_return(migration_date + 2)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to eq('p6')
        end

        it 'day +7 is start of p7 (in p7)' do
          allow(Time.zone).to receive(:today).and_return(migration_date + 7)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to eq('p7')
        end
      end

      context 'when today is one day before phase boundary' do
        it 'day -61 is before p0 (not yet started)' do
          allow(Time.zone).to receive(:today).and_return(migration_date - 61)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to be_nil
        end

        it 'day -46 is still in p0' do
          allow(Time.zone).to receive(:today).and_return(migration_date - 46)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to eq('p0')
        end
      end
    end

    context 'Current Phase' do
      let(:user_facility_ids) { %w[516] }
      let(:migration_date) { Date.new(2026, 3, 3) }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }

      it 'includes current phase in phases hash' do
        allow(Time.zone).to receive(:today).and_return(migration_date - 30)
        result = service.get_oh_migration_info
        expect(result.first[:phases]).to have_key(:current)
      end

      context 'when in middle of a phase' do
        it 'day -50 is in p0' do
          allow(Time.zone).to receive(:today).and_return(migration_date - 50)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to eq('p0')
        end

        it 'day -35 is in p1' do
          allow(Time.zone).to receive(:today).and_return(migration_date - 35)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to eq('p1')
        end

        it 'day +5 is in p6' do
          allow(Time.zone).to receive(:today).and_return(migration_date + 5)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to eq('p6')
        end
      end
    end

    context 'Migration Status' do
      let(:user_facility_ids) { %w[516] }
      let(:migration_date) { Date.new(2026, 3, 3) }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }

      it 'includes migration_status in response' do
        result = service.get_oh_migration_info
        expect(result.first).to have_key(:migration_status)
      end

      context 'when before p0' do
        it 'returns NOT_STARTED' do
          allow(Time.zone).to receive(:today).and_return(migration_date - 61)
          result = service.get_oh_migration_info
          expect(result.first[:migration_status]).to eq('NOT_STARTED')
        end
      end

      context 'when at p0' do
        it 'returns ACTIVE' do
          allow(Time.zone).to receive(:today).and_return(migration_date - 60)
          result = service.get_oh_migration_info
          expect(result.first[:migration_status]).to eq('ACTIVE')
        end
      end

      context 'when in middle of active window' do
        it 'returns ACTIVE' do
          allow(Time.zone).to receive(:today).and_return(migration_date - 30)
          result = service.get_oh_migration_info
          expect(result.first[:migration_status]).to eq('ACTIVE')
        end
      end

      context 'when at p7' do
        it 'returns ACTIVE' do
          allow(Time.zone).to receive(:today).and_return(migration_date + 7)
          result = service.get_oh_migration_info
          expect(result.first[:migration_status]).to eq('ACTIVE')
        end
      end

      context 'when after p7' do
        it 'returns COMPLETE' do
          allow(Time.zone).to receive(:today).and_return(migration_date + 8)
          result = service.get_oh_migration_info
          expect(result.first[:migration_status]).to eq('COMPLETE')
        end
      end
    end

    context 'Current Phase Nil Cases' do
      let(:user_facility_ids) { %w[516] }
      let(:migration_date) { Date.new(2026, 3, 3) }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }

      context 'when migration_status is NOT_STARTED' do
        it 'current phase is nil' do
          allow(Time.zone).to receive(:today).and_return(migration_date - 61)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to be_nil
        end
      end

      context 'when migration_status is COMPLETE' do
        it 'current phase is p7' do
          # After p7 the current phase will be p7 (the last phase we passed)
          allow(Time.zone).to receive(:today).and_return(migration_date + 10)
          result = service.get_oh_migration_info
          expect(result.first[:phases][:current]).to eq('p7')
        end
      end
    end

    context 'All Statuses Returned' do
      let(:user_facility_ids) { %w[516 517 518] }
      let(:today) { Date.new(2026, 3, 15) }
      # Facility 516: migration 2026-01-01 (complete - more than 7 days past)
      # Facility 517: migration 2026-03-15 (active - today is migration day)
      # Facility 518: migration 2026-06-01 (not started - more than 60 days away)
      let(:oh_migrations_list) do
        '2026-01-01:[516,Columbus VA];2026-03-15:[517,Toledo VA];2026-06-01:[518,Cleveland VA]'
      end

      before do
        allow(Time.zone).to receive(:today).and_return(today)
      end

      it 'returns all migrations regardless of status' do
        result = service.get_oh_migration_info
        expect(result.length).to eq(3)
      end

      it 'includes COMPLETE migrations' do
        result = service.get_oh_migration_info
        statuses = result.map { |r| r[:migration_status] }
        expect(statuses).to include('COMPLETE')
      end

      it 'includes ACTIVE migrations' do
        result = service.get_oh_migration_info
        statuses = result.map { |r| r[:migration_status] }
        expect(statuses).to include('ACTIVE')
      end

      it 'includes NOT_STARTED migrations' do
        result = service.get_oh_migration_info
        statuses = result.map { |r| r[:migration_status] }
        expect(statuses).to include('NOT_STARTED')
      end
    end

    context 'Response Structure' do
      let(:user_facility_ids) { %w[516 517] }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA],[517,Toledo VA]' }

      it 'returns array of migration info objects' do
        result = service.get_oh_migration_info
        expect(result).to be_an(Array)
        expect(result.first).to be_a(Hash)
      end

      it 'includes migration_date' do
        result = service.get_oh_migration_info
        expect(result.first).to have_key(:migration_date)
      end

      it 'includes migration_status' do
        result = service.get_oh_migration_info
        expect(result.first).to have_key(:migration_status)
      end

      it 'includes facilities array' do
        result = service.get_oh_migration_info
        expect(result.first).to have_key(:facilities)
        expect(result.first[:facilities]).to be_an(Array)
      end

      it 'includes phases hash' do
        result = service.get_oh_migration_info
        expect(result.first).to have_key(:phases)
        expect(result.first[:phases]).to be_a(Hash)
      end

      it 'facilities include id and name' do
        result = service.get_oh_migration_info
        facility = result.first[:facilities].first
        expect(facility).to have_key(:id)
        expect(facility).to have_key(:name)
      end
    end

    context 'Edge Cases' do
      let(:user_facility_ids) { %w[516] }

      context 'with malformed date in config' do
        let(:oh_migrations_list) { 'invalid-date:[516,Columbus VA]' }

        it 'returns empty array and logs error' do
          expect(Rails.logger).to receive(:error).with('OH Migration Info Error: Failed to build migration response',
                                                       hash_including(:error_class, :error_message))
          result = service.get_oh_migration_info
          expect(result).to eq([])
        end
      end

      context 'with missing facility data' do
        let(:oh_migrations_list) { '2026-03-03:[]' }

        it 'returns empty array' do
          result = service.get_oh_migration_info
          expect(result).to eq([])
        end
      end

      context 'with facility missing name' do
        # Facility entry with only ID (no name) is silently filtered out during parsing
        let(:oh_migrations_list) { '2026-03-03:[516]' }

        it 'returns empty array' do
          result = service.get_oh_migration_info
          expect(result).to eq([])
        end
      end

      context 'with whitespace in config' do
        let(:oh_migrations_list) { '  2026-03-03 : [ 516 , Columbus VA ]  ' }

        it 'handles whitespace correctly' do
          result = service.get_oh_migration_info
          expect(result.length).to eq(1)
          expect(result.first[:facilities].first[:id]).to eq('516')
        end
      end
    end

    context 'Error Handling' do
      let(:user_facility_ids) { %w[516] }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }

      context 'when an unexpected error occurs' do
        before do
          allow(service).to receive(:parse_oh_migrations_list).and_raise(StandardError.new('Test error'))
        end

        it 'logs the error with specific message' do
          expect(Rails.logger).to receive(:error).with('OH Migration Info Error: Failed to build migration response',
                                                       anything)
          service.get_oh_migration_info
        end

        it 'returns empty array' do
          allow(Rails.logger).to receive(:error)
          result = service.get_oh_migration_info
          expect(result).to eq([])
        end

        it 'does not raise the error' do
          allow(Rails.logger).to receive(:error)
          expect { service.get_oh_migration_info }.not_to raise_error
        end
      end
    end
  end
end
