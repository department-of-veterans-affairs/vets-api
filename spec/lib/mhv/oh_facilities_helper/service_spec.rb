# frozen_string_literal: true

require 'rails_helper'
require 'mhv/oh_facilities_helper/service'

RSpec.describe MHV::OhFacilitiesHelper::Service do
  subject(:service) { described_class.new(user) }

  let(:user) { build(:user) }
  let(:va_treatment_facility_ids) { %w[516 553] }
  let(:pretransitioned_oh_facilities) { '516, 517, 518' }
  let(:facilities_ready_for_info_alert) { '553, 554' }

  before do
    allow(user).to receive(:va_treatment_facility_ids).and_return(va_treatment_facility_ids)
    allow(Settings.mhv.oh_facility_checks).to receive_messages(
      pretransitioned_oh_facilities:,
      facilities_ready_for_info_alert:
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

      it 'returns true' do
        expect(service.user_facility_ready_for_info_alert?).to be true
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

      it 'returns true' do
        expect(service.user_facility_ready_for_info_alert?).to be true
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

  describe '#get_migration_schedules' do
    let(:user) { build(:user, :loa3) }
    let(:user_facility_ids) { %w[516 517] }
    let(:service) { described_class.new(user) }
    let(:oh_migrations_list) { nil }

    before do
      allow(user).to receive(:va_treatment_facility_ids).and_return(user_facility_ids)
      allow(Settings.mhv.oh_facility_checks).to receive(:oh_migrations_list).and_return(oh_migrations_list)
    end

    context 'Parsing' do
      context 'when oh_migrations_list is nil' do
        let(:oh_migrations_list) { nil }

        it 'returns an empty array' do
          expect(service.get_migration_schedules).to eq([])
        end
      end

      context 'when oh_migrations_list is empty string' do
        let(:oh_migrations_list) { '' }

        it 'returns an empty array' do
          expect(service.get_migration_schedules).to eq([])
        end
      end

      context 'when oh_migrations_list is whitespace only' do
        let(:oh_migrations_list) { '   ' }

        it 'returns an empty array' do
          expect(service.get_migration_schedules).to eq([])
        end
      end

      context 'when oh_migrations_list has valid format' do
        let(:user_facility_ids) { %w[516] }
        let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA Medical Center]' }

        it 'parses the migration entry correctly' do
          result = service.get_migration_schedules
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
          result = service.get_migration_schedules
          expect(result.length).to eq(3)
        end
      end
    end

    context 'Facility Extraction' do
      context 'when user has matching facilities' do
        let(:user_facility_ids) { %w[516 517] }
        let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA],[517,Toledo VA],[999,Other VA]' }

        it 'only includes facilities matching user va_treatment_facility_ids' do
          result = service.get_migration_schedules
          expect(result.length).to eq(1)
          facility_ids = result.first[:facilities].map { |f| f[:facility_id] }
          expect(facility_ids).to contain_exactly('516', '517')
        end
      end

      context 'when user has no matching facilities' do
        let(:user_facility_ids) { %w[999 888] }
        let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }

        it 'returns an empty array' do
          expect(service.get_migration_schedules).to eq([])
        end
      end

      context 'when user has empty facility list' do
        let(:user_facility_ids) { [] }
        let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }

        it 'returns an empty array' do
          expect(service.get_migration_schedules).to eq([])
        end
      end
    end

    context 'Facility Merging' do
      let(:user_facility_ids) { %w[516 517] }

      context 'when multiple facilities share the same migration date' do
        let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA],[517,Toledo VA]' }

        it 'merges them into a single entry' do
          result = service.get_migration_schedules
          expect(result.length).to eq(1)
          expect(result.first[:facilities].length).to eq(2)
        end
      end

      context 'when facilities have different migration dates' do
        let(:user_facility_ids) { %w[516 517] }
        let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA];2026-04-01:[517,Toledo VA]' }

        it 'returns separate entries' do
          result = service.get_migration_schedules
          expect(result.length).to eq(2)
        end
      end
    end

    context 'Phase Dates' do
      let(:user_facility_ids) { %w[516] }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }
      let(:migration_date) { Date.new(2026, 3, 3) }
      let(:phases_constant) { MHV::OhFacilitiesHelper::Service::PHASES }

      it 'includes all phases defined in PHASES constant plus current' do
        result = service.get_migration_schedules
        phases = result.first[:phases]
        expect(phases.keys).to include(:current, *phases_constant.keys)
      end

      it 'calculates each phase date by adding the offset to migration date' do
        result = service.get_migration_schedules
        phases = result.first[:phases]

        phases_constant.each do |phase_name, day_offset|
          expected_date = (migration_date + day_offset).strftime('%B %-d, %Y')
          expect(phases[phase_name]).to eq(expected_date),
                                        "Expected #{phase_name} to be #{expected_date}, got #{phases[phase_name]}"
        end
      end

      it 'phase dates are in chronological order from p0 to p7' do
        result = service.get_migration_schedules
        phases = result.first[:phases]

        phase_dates = phases_constant.keys.map do |phase_name|
          Date.strptime(phases[phase_name], '%B %d, %Y')
        end

        expect(phase_dates).to eq(phase_dates.sort)
      end
    end

    context 'Date Formatting' do
      let(:user_facility_ids) { %w[516] }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }

      it 'formats migration_date as human-readable string' do
        result = service.get_migration_schedules
        expect(result.first[:migration_date]).to eq('March 3, 2026')
      end

      it 'formats phase dates as human-readable strings' do
        result = service.get_migration_schedules
        # Check p5 (the migration date itself)
        expect(result.first[:phases][:p5]).to eq('March 3, 2026')
      end

      context 'with single-digit day' do
        let(:oh_migrations_list) { '2026-01-05:[516,Columbus VA]' }

        it 'formats without leading zero on day' do
          result = service.get_migration_schedules
          expect(result.first[:migration_date]).to eq('January 5, 2026')
        end
      end
    end

    context 'Phase Boundaries (Inclusive)' do
      let(:user_facility_ids) { %w[516] }
      let(:migration_date) { Date.new(2026, 3, 3) }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }
      let(:phases) { described_class::PHASES }

      context 'when today is exactly at phase boundary' do
        it 'returns correct phase when today equals each phase start date' do
          phases.each do |phase_key, day_offset|
            allow(Time.zone).to receive(:today).and_return(migration_date + day_offset)
            result = service.get_migration_schedules
            current_phase = result.first[:phases][:current]
            expect(current_phase).to eq(phase_key.to_s),
                                     "Expected #{phase_key} on day #{day_offset} but was #{current_phase}"
          end
        end
      end

      context 'when today is one day before first phase boundary' do
        it 'current phase is nil (not yet started)' do
          first_phase_offset = phases.values.min
          allow(Time.zone).to receive(:today).and_return(migration_date + first_phase_offset - 1)
          result = service.get_migration_schedules
          expect(result.first[:phases][:current]).to be_nil
        end
      end

      context 'when today is between first two phases' do
        it 'returns first phase' do
          sorted_offsets = phases.values.sort
          first_offset = sorted_offsets[0]
          second_offset = sorted_offsets[1]
          midpoint = first_offset + ((second_offset - first_offset) / 2)
          allow(Time.zone).to receive(:today).and_return(migration_date + midpoint)
          result = service.get_migration_schedules
          expect(result.first[:phases][:current]).to eq(phases.key(first_offset).to_s)
        end
      end
    end

    context 'Current Phase' do
      let(:user_facility_ids) { %w[516] }
      let(:migration_date) { Date.new(2026, 3, 3) }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }
      let(:phases) { described_class::PHASES }

      context 'when in middle of a phase' do
        it 'returns correct phase when today is between phase boundaries' do
          sorted_phases = phases.sort_by { |_, offset| offset }

          sorted_phases.each_with_index do |(phase_key, offset), index|
            next_offset = sorted_phases[index + 1]&.last

            # Test midpoint between this phase and next (or +1 day if last phase)
            midpoint = if next_offset
                         offset + ((next_offset - offset) / 2)
                       else
                         offset + 1
                       end

            allow(Time.zone).to receive(:today).and_return(migration_date + midpoint)
            result = service.get_migration_schedules
            current_phase = result.first[:phases][:current]
            expect(current_phase).to eq(phase_key.to_s),
                                     "Expected #{phase_key} on day #{midpoint} but was #{current_phase}"
          end
        end
      end
    end

    context 'Migration Status' do
      let(:user_facility_ids) { %w[516] }
      let(:migration_date) { Date.new(2026, 3, 3) }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }
      let(:phases) { described_class::PHASES }
      let(:first_phase_offset) { phases.values.min }
      let(:last_phase_offset) { phases.values.max }

      context 'when before first phase' do
        it 'returns NOT_STARTED' do
          allow(Time.zone).to receive(:today).and_return(migration_date + first_phase_offset - 1)
          result = service.get_migration_schedules
          expect(result.first[:migration_status]).to eq(described_class::MIGRATION_STATUS[:not_started])
        end
      end

      context 'when at first phase' do
        it 'returns ACTIVE' do
          allow(Time.zone).to receive(:today).and_return(migration_date + first_phase_offset)
          result = service.get_migration_schedules
          expect(result.first[:migration_status]).to eq(described_class::MIGRATION_STATUS[:active])
        end
      end

      context 'when in middle of active window' do
        it 'returns ACTIVE' do
          midpoint = (first_phase_offset + last_phase_offset) / 2
          allow(Time.zone).to receive(:today).and_return(migration_date + midpoint)
          result = service.get_migration_schedules
          expect(result.first[:migration_status]).to eq(described_class::MIGRATION_STATUS[:active])
        end
      end

      context 'when at last phase' do
        it 'returns ACTIVE' do
          allow(Time.zone).to receive(:today).and_return(migration_date + last_phase_offset)
          result = service.get_migration_schedules
          expect(result.first[:migration_status]).to eq(described_class::MIGRATION_STATUS[:active])
        end
      end

      context 'when after last phase' do
        it 'returns COMPLETE' do
          allow(Time.zone).to receive(:today).and_return(migration_date + last_phase_offset + 1)
          result = service.get_migration_schedules
          expect(result.first[:migration_status]).to eq(described_class::MIGRATION_STATUS[:complete])
        end
      end
    end

    context 'Current Phase Nil Cases' do
      let(:user_facility_ids) { %w[516] }
      let(:migration_date) { Date.new(2026, 3, 3) }
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA]' }
      let(:phases) { described_class::PHASES }
      let(:first_phase_offset) { phases.values.min }
      let(:last_phase_offset) { phases.values.max }
      let(:last_phase_key) { phases.key(last_phase_offset).to_s }

      context 'when migration_status is NOT_STARTED' do
        it 'current phase is nil' do
          allow(Time.zone).to receive(:today).and_return(migration_date + first_phase_offset - 1)
          result = service.get_migration_schedules
          expect(result.first[:phases][:current]).to be_nil
        end
      end

      context 'when migration_status is COMPLETE' do
        it 'current phase is last phase' do
          # After last phase the current phase will be the last phase (the last phase we passed)
          allow(Time.zone).to receive(:today).and_return(migration_date + last_phase_offset + 3)
          result = service.get_migration_schedules
          expect(result.first[:phases][:current]).to eq(last_phase_key)
        end
      end
    end

    context 'All Statuses Returned' do
      let(:user_facility_ids) { %w[516 517 518] }
      let(:phases) { described_class::PHASES }
      let(:first_phase_offset) { phases.values.min }
      let(:last_phase_offset) { phases.values.max }
      let(:today) { Date.new(2026, 3, 15) }
      # Facility 516: migration far in past (complete - past last phase)
      # Facility 517: migration today (active - at migration day p5)
      # Facility 518: migration far in future (not started - before first phase)
      let(:complete_migration_date) { today - last_phase_offset - 10 }
      let(:active_migration_date) { today }
      let(:not_started_migration_date) { today - first_phase_offset + 10 }
      let(:oh_migrations_list) do
        [
          "#{complete_migration_date}:[516,Columbus VA]",
          "#{active_migration_date}:[517,Toledo VA]",
          "#{not_started_migration_date}:[518,Cleveland VA]"
        ].join(';')
      end

      before do
        allow(Time.zone).to receive(:today).and_return(today)
      end

      it 'returns all migrations regardless of status' do
        result = service.get_migration_schedules
        expect(result.length).to eq(3)
      end

      it 'includes COMPLETE migrations' do
        result = service.get_migration_schedules
        statuses = result.map { |r| r[:migration_status] }
        expect(statuses).to include(described_class::MIGRATION_STATUS[:complete])
      end

      it 'includes ACTIVE migrations' do
        result = service.get_migration_schedules
        statuses = result.map { |r| r[:migration_status] }
        expect(statuses).to include(described_class::MIGRATION_STATUS[:active])
      end

      it 'includes NOT_STARTED migrations' do
        result = service.get_migration_schedules
        statuses = result.map { |r| r[:migration_status] }
        expect(statuses).to include(described_class::MIGRATION_STATUS[:not_started])
      end
    end

    context 'Edge Cases' do
      let(:user_facility_ids) { %w[516] }

      context 'with malformed date in config' do
        let(:oh_migrations_list) { 'invalid-date:[516,Columbus VA]' }

        it 'returns empty array and logs error' do
          expect(Rails.logger).to receive(:error).with('OH Migration Info Error: Failed to build migration response',
                                                       hash_including(:error_class, :error_message))
          result = service.get_migration_schedules
          expect(result).to eq([])
        end
      end

      context 'with missing facility data' do
        let(:oh_migrations_list) { '2026-03-03:[]' }

        it 'returns empty array' do
          result = service.get_migration_schedules
          expect(result).to eq([])
        end
      end

      context 'with facility missing name' do
        # Facility entry with only ID (no name) is silently filtered out during parsing
        let(:oh_migrations_list) { '2026-03-03:[516]' }

        it 'returns empty array' do
          result = service.get_migration_schedules
          expect(result).to eq([])
        end
      end

      context 'with whitespace in config' do
        let(:oh_migrations_list) { '  2026-03-03 : [ 516 , Columbus VA ]  ' }

        it 'handles whitespace correctly' do
          result = service.get_migration_schedules
          expect(result.length).to eq(1)
          expect(result.first[:facilities].first[:facility_id]).to eq('516')
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
          service.get_migration_schedules
        end

        it 'returns empty array' do
          allow(Rails.logger).to receive(:error)
          result = service.get_migration_schedules
          expect(result).to eq([])
        end

        it 'does not raise the error' do
          allow(Rails.logger).to receive(:error)
          expect { service.get_migration_schedules }.not_to raise_error
        end
      end
    end
  end

  describe '#get_phase_for_station_number' do
    let(:user) { build(:user, :loa3) }
    let(:service) { described_class.new(user) }
    let(:oh_migrations_list) { nil }

    before do
      allow(Settings.mhv.oh_facility_checks).to receive(:oh_migrations_list).and_return(oh_migrations_list)
    end

    context 'when station_number is blank' do
      it 'returns nil for nil station_number' do
        expect(service.get_phase_for_station_number(nil)).to be_nil
      end

      it 'returns nil for empty string station_number' do
        expect(service.get_phase_for_station_number('')).to be_nil
      end
    end

    context 'when oh_migrations_list is not configured' do
      let(:oh_migrations_list) { nil }

      it 'returns nil' do
        expect(service.get_phase_for_station_number('516')).to be_nil
      end
    end

    context 'when oh_migrations_list is empty' do
      let(:oh_migrations_list) { '' }

      it 'returns nil' do
        expect(service.get_phase_for_station_number('516')).to be_nil
      end
    end

    context 'when station_number is not in the migrations list' do
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA],[517,Other VA]' }

      it 'returns nil' do
        expect(service.get_phase_for_station_number('999')).to be_nil
      end
    end

    context 'when station_number is in the migrations list' do
      let(:migration_date) { Time.zone.today + 30 }
      let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA],[517,Other VA]" }

      it 'returns the current phase for the matching facility' do
        result = service.get_phase_for_station_number('516')
        expect(result).to be_a(String).or be_nil
      end
    end

    context 'phase determination based on migration date' do
      # Migration date in the future - before p0 (more than 60 days away)
      context 'when migration is more than 60 days away (before p0)' do
        let(:migration_date) { Time.zone.today + 100 }
        let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA]" }

        it 'returns nil (NOT_STARTED)' do
          expect(service.get_phase_for_station_number('516')).to be_nil
        end
      end

      # p0: 60 days before migration
      context 'when migration is 60 days away (p0)' do
        let(:migration_date) { Time.zone.today + 60 }
        let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA]" }

        it 'returns p0' do
          expect(service.get_phase_for_station_number('516')).to eq('p0')
        end
      end

      # p1: 45 days before migration
      context 'when migration is 45 days away (p1)' do
        let(:migration_date) { Time.zone.today + 45 }
        let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA]" }

        it 'returns p1' do
          expect(service.get_phase_for_station_number('516')).to eq('p1')
        end
      end

      # p2: 30 days before migration
      context 'when migration is 30 days away (p2)' do
        let(:migration_date) { Time.zone.today + 30 }
        let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA]" }

        it 'returns p2' do
          expect(service.get_phase_for_station_number('516')).to eq('p2')
        end
      end

      # p3: 6 days before migration
      context 'when migration is 6 days away (p3)' do
        let(:migration_date) { Time.zone.today + 6 }
        let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA]" }

        it 'returns p3' do
          expect(service.get_phase_for_station_number('516')).to eq('p3')
        end
      end

      # p4: 3 days before migration
      context 'when migration is 3 days away (p4)' do
        let(:migration_date) { Time.zone.today + 3 }
        let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA]" }

        it 'returns p4' do
          expect(service.get_phase_for_station_number('516')).to eq('p4')
        end
      end

      # p5: migration day
      context 'when today is migration day (p5)' do
        let(:migration_date) { Time.zone.today }
        let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA]" }

        it 'returns p5' do
          expect(service.get_phase_for_station_number('516')).to eq('p5')
        end
      end

      # p6: 2 days after migration
      context 'when migration was 2 days ago (p6)' do
        let(:migration_date) { Time.zone.today - 2 }
        let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA]" }

        it 'returns p6' do
          expect(service.get_phase_for_station_number('516')).to eq('p6')
        end
      end

      # p7: 7 days after migration
      context 'when migration was 7 days ago (p7)' do
        let(:migration_date) { Time.zone.today - 7 }
        let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA]" }

        it 'returns p7' do
          expect(service.get_phase_for_station_number('516')).to eq('p7')
        end
      end

      # After p7 (complete)
      context 'when migration was more than 7 days ago (complete)' do
        let(:migration_date) { Time.zone.today - 10 }
        let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA]" }

        it 'returns p7 (last phase)' do
          expect(service.get_phase_for_station_number('516')).to eq('p7')
        end
      end
    end

    context 'with multiple migrations in the list' do
      let(:oh_migrations_list) do
        date1 = (Time.zone.today + 30).strftime('%Y-%m-%d')
        date2 = (Time.zone.today + 60).strftime('%Y-%m-%d')
        "#{date1}:[516,Columbus VA];#{date2}:[517,Other VA]"
      end

      it 'returns the phase for the correct facility' do
        expect(service.get_phase_for_station_number('516')).to eq('p2')
        expect(service.get_phase_for_station_number('517')).to eq('p0')
      end
    end

    context 'when station_number is numeric' do
      let(:migration_date) { Time.zone.today + 30 }
      let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA]" }

      it 'converts to string and matches correctly' do
        expect(service.get_phase_for_station_number(516)).to eq('p2')
      end
    end

    context 'Error Handling' do
      context 'when date parsing fails' do
        let(:oh_migrations_list) { 'invalid-date:[516,Columbus VA]' }

        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with('OH Migration Phase Batch Lookup Error', anything)
          service.get_phase_for_station_number('516')
        end

        it 'returns nil' do
          allow(Rails.logger).to receive(:error)
          expect(service.get_phase_for_station_number('516')).to be_nil
        end

        it 'does not raise an error' do
          allow(Rails.logger).to receive(:error)
          expect { service.get_phase_for_station_number('516') }.not_to raise_error
        end
      end
    end
  end

  describe '#get_phases_for_station_numbers' do
    let(:user) { build(:user, :loa3) }
    let(:service) { described_class.new(user) }
    let(:oh_migrations_list) { nil }

    before do
      allow(Settings.mhv.oh_facility_checks).to receive(:oh_migrations_list).and_return(oh_migrations_list)
    end

    context 'when station_numbers is blank' do
      it 'returns empty hash for nil' do
        expect(service.get_phases_for_station_numbers(nil)).to eq({})
      end

      it 'returns empty hash for empty array' do
        expect(service.get_phases_for_station_numbers([])).to eq({})
      end
    end

    context 'when oh_migrations_list is not configured' do
      let(:oh_migrations_list) { nil }

      it 'returns empty hash' do
        expect(service.get_phases_for_station_numbers(%w[516 517])).to eq({})
      end
    end

    context 'when oh_migrations_list is empty' do
      let(:oh_migrations_list) { '' }

      it 'returns empty hash' do
        expect(service.get_phases_for_station_numbers(%w[516 517])).to eq({})
      end
    end

    context 'when no station_numbers are in the migrations list' do
      let(:oh_migrations_list) { '2026-03-03:[516,Columbus VA],[517,Other VA]' }

      it 'returns empty hash' do
        expect(service.get_phases_for_station_numbers(%w[999 888])).to eq({})
      end
    end

    context 'when some station_numbers are in the migrations list' do
      let(:migration_date) { Time.zone.today + 30 }
      let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA],[517,Other VA]" }

      it 'returns phases only for matching facilities' do
        result = service.get_phases_for_station_numbers(%w[516 999])
        expect(result).to eq({ '516' => 'p2' })
      end
    end

    context 'when all station_numbers are in the migrations list' do
      let(:migration_date) { Time.zone.today + 30 }
      let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA],[517,Other VA]" }

      it 'returns phases for all matching facilities' do
        result = service.get_phases_for_station_numbers(%w[516 517])
        expect(result).to eq({ '516' => 'p2', '517' => 'p2' })
      end
    end

    context 'with multiple migrations in the list' do
      let(:oh_migrations_list) do
        date1 = (Time.zone.today + 30).strftime('%Y-%m-%d')
        date2 = (Time.zone.today + 6).strftime('%Y-%m-%d')
        "#{date1}:[516,Columbus VA];#{date2}:[517,Other VA]"
      end

      it 'returns correct phases for facilities in different migrations' do
        result = service.get_phases_for_station_numbers(%w[516 517])
        expect(result).to eq({ '516' => 'p2', '517' => 'p3' })
      end
    end

    context 'when station_numbers are numeric' do
      let(:migration_date) { Time.zone.today + 30 }
      let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA]" }

      it 'converts to string and matches correctly' do
        result = service.get_phases_for_station_numbers([516, 517])
        expect(result).to eq({ '516' => 'p2' })
      end
    end

    context 'with duplicate station_numbers in input' do
      let(:migration_date) { Time.zone.today + 30 }
      let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA]" }

      it 'returns unique results' do
        result = service.get_phases_for_station_numbers(%w[516 516 516])
        expect(result).to eq({ '516' => 'p2' })
      end
    end

    context 'Error Handling' do
      context 'when date parsing fails' do
        let(:oh_migrations_list) { 'invalid-date:[516,Columbus VA]' }

        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with('OH Migration Phase Batch Lookup Error', anything)
          service.get_phases_for_station_numbers(%w[516])
        end

        it 'returns empty hash' do
          allow(Rails.logger).to receive(:error)
          expect(service.get_phases_for_station_numbers(%w[516])).to eq({})
        end

        it 'does not raise an error' do
          allow(Rails.logger).to receive(:error)
          expect { service.get_phases_for_station_numbers(%w[516]) }.not_to raise_error
        end
      end
    end

    context 'performance optimization' do
      let(:migration_date) { Time.zone.today + 30 }
      let(:oh_migrations_list) { "#{migration_date.strftime('%Y-%m-%d')}:[516,Columbus VA],[517,Other VA]" }

      it 'parses migrations list only once for multiple lookups' do
        expect(service).to receive(:parse_oh_migrations_list).once.and_call_original
        service.get_phases_for_station_numbers(%w[516 517])
      end
    end
  end

  describe '#get_soonest_migration_phase' do
    let(:user) { build(:user, :mhv) }
    let(:service) { described_class.new(user) }

    before do
      allow(Settings.mhv.oh_facility_checks).to receive(:oh_migrations_list).and_return(oh_migrations_list)
    end

    context 'when oh_migrations_list is blank' do
      let(:oh_migrations_list) { nil }

      it 'returns nil' do
        expect(service.get_soonest_migration_phase).to be_nil
      end
    end

    context 'when oh_migrations_list is empty string' do
      let(:oh_migrations_list) { '' }

      it 'returns nil' do
        expect(service.get_soonest_migration_phase).to be_nil
      end
    end

    context 'when there is a single migration date' do
      let(:oh_migrations_list) { "#{(Time.zone.today + 5.days).strftime('%Y-%m-%d')}:[516,Columbus VA]" }

      it 'returns the current phase of that migration' do
        expect(service.get_soonest_migration_phase).to eq('p3')
      end
    end

    context 'when there are multiple migration dates' do
      let(:far_date) { (Time.zone.today + 50.days).strftime('%Y-%m-%d') }
      let(:near_date) { (Time.zone.today + 2.days).strftime('%Y-%m-%d') }
      let(:oh_migrations_list) { "#{far_date}:[516,Columbus VA];#{near_date}:[517,Cleveland VA]" }

      it 'returns the current phase of the soonest migration' do
        # near_date is 2 days away, which is p4
        expect(service.get_soonest_migration_phase).to eq('p4')
      end
    end

    context 'when soonest migration is in p6 phase' do
      let(:past_date) { (Time.zone.today - 3.days).strftime('%Y-%m-%d') }
      let(:oh_migrations_list) { "#{past_date}:[516,Columbus VA]" }

      it 'returns p6' do
        expect(service.get_soonest_migration_phase).to eq('p6')
      end
    end

    context 'when all migration dates have invalid format' do
      let(:oh_migrations_list) { 'invalid-date:[516,Columbus VA]' }

      it 'returns nil' do
        allow(Rails.logger).to receive(:error)
        expect(service.get_soonest_migration_phase).to be_nil
      end
    end

    context 'when some migration dates are invalid but some are valid' do
      let(:valid_date) { (Time.zone.today + 5.days).strftime('%Y-%m-%d') }
      let(:oh_migrations_list) { "invalid-date:[516,Columbus VA];#{valid_date}:[517,Cleveland VA]" }

      it 'returns the phase of the valid migration date' do
        expect(service.get_soonest_migration_phase).to eq('p3')
      end
    end
  end
end
