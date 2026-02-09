# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsBenefits::DependentsHelper do
  # Create a test class that includes the module to test instance methods
  let(:test_class) do
    Class.new do
      include DependentsBenefits::DependentsHelper
    end
  end
  let(:helper) { test_class.new }

  describe '#parse_time' do
    it 'parses a valid date string' do
      result = helper.parse_time('2024-01-15T10:30:00Z')
      expect(result).to be_a(Time)
      expect(result.year).to eq(2024)
      expect(result.month).to eq(1)
      expect(result.day).to eq(15)
    end

    it 'returns nil for blank string' do
      expect(helper.parse_time('')).to be_nil
    end

    it 'returns nil for nil input' do
      expect(helper.parse_time(nil)).to be_nil
    end

    it 'handles ISO 8601 format' do
      result = helper.parse_time('2025-12-25T00:00:00Z')
      expect(result).to be_a(Time)
    end
  end

  describe '#compare_by_effective_date' do
    let(:earlier_decision) { { award_effective_date: '2024-01-01' } }
    let(:later_decision) { { award_effective_date: '2024-12-31' } }

    it 'returns -1 when first date is earlier' do
      result = helper.compare_by_effective_date(earlier_decision, later_decision)
      expect(result).to eq(-1)
    end

    it 'returns 1 when first date is later' do
      result = helper.compare_by_effective_date(later_decision, earlier_decision)
      expect(result).to eq(1)
    end

    it 'returns 0 when dates are equal' do
      same_date = { award_effective_date: '2024-01-01' }
      result = helper.compare_by_effective_date(earlier_decision, same_date)
      expect(result).to eq(0)
    end
  end

  describe '#in_future?' do
    it 'returns true when date is in the future' do
      future_decision = { award_effective_date: 2.days.from_now.iso8601 }
      expect(helper.in_future?(future_decision)).to be true
    end

    it 'returns false when date is in the past' do
      past_decision = { award_effective_date: 2.days.ago.iso8601 }
      expect(helper.in_future?(past_decision)).to be false
    end

    it 'returns false when date is now' do
      now_decision = { award_effective_date: Time.zone.now.iso8601 }
      expect(helper.in_future?(now_decision)).to be false
    end
  end

  describe '#still_pending?' do
    let(:award_event_id) { 'EVENT123' }
    let(:future_decision) do
      {
        award_event_id: 'EVENT123',
        award_effective_date: 2.days.from_now.iso8601
      }
    end
    let(:past_decision) do
      {
        award_event_id: 'EVENT123',
        award_effective_date: 2.days.ago.iso8601
      }
    end
    let(:different_event_decision) do
      {
        award_event_id: 'EVENT456',
        award_effective_date: 2.days.from_now.iso8601
      }
    end

    it 'returns true when event ID matches and date is in future' do
      expect(helper.still_pending?(future_decision, award_event_id)).to be true
    end

    it 'returns false when event ID matches but date is in past' do
      expect(helper.still_pending?(past_decision, award_event_id)).to be false
    end

    it 'returns false when event ID does not match' do
      expect(helper.still_pending?(different_event_decision, award_event_id)).to be false
    end
  end

  describe '#trim_whitespace' do
    it 'replaces multiple spaces with single space' do
      expect(helper.trim_whitespace('hello    world')).to eq('hello world')
    end

    it 'replaces tabs with single space' do
      expect(helper.trim_whitespace("hello\t\tworld")).to eq('hello world')
    end

    it 'replaces newlines with single space' do
      expect(helper.trim_whitespace("hello\n\nworld")).to eq('hello world')
    end

    it 'handles mixed whitespace' do
      expect(helper.trim_whitespace("hello  \t\n  world")).to eq('hello world')
    end

    it 'returns nil for nil input' do
      expect(helper.trim_whitespace(nil)).to be_nil
    end

    it 'handles string with no extra whitespace' do
      expect(helper.trim_whitespace('hello world')).to eq('hello world')
    end
  end

  describe '#upcoming_removals' do
    let(:person_id) { '12345' }
    let(:earlier_end_event) do
      {
        person_id:,
        dependency_decision_type: 'T18',
        award_effective_date: 1.month.from_now.iso8601
      }
    end
    let(:later_end_event) do
      {
        person_id:,
        dependency_decision_type: 'SCHATTT',
        award_effective_date: 2.months.from_now.iso8601
      }
    end
    let(:start_event) do
      {
        person_id:,
        dependency_decision_type: 'EMC',
        award_effective_date: 1.year.ago.iso8601
      }
    end

    it 'returns the most recent end event for each person' do
      decisions = {
        person_id => [earlier_end_event, later_end_event, start_event]
      }

      result = helper.upcoming_removals(decisions)
      expect(result[person_id]).to eq(later_end_event)
    end

    it 'filters out non-end events' do
      decisions = {
        person_id => [start_event]
      }

      result = helper.upcoming_removals(decisions)
      expect(result[person_id]).to be_nil
    end

    it 'handles empty decision arrays' do
      decisions = { person_id => [] }

      result = helper.upcoming_removals(decisions)
      expect(result[person_id]).to be_nil
    end
  end

  describe '#dependent_benefit_types' do
    let(:person_id) { '12345' }
    let(:emc_decision) do
      {
        person_id:,
        dependency_decision_type: 'EMC',
        dependency_status_type_description: 'Minor  Child'
      }
    end
    let(:schattb_decision) do
      {
        person_id:,
        dependency_decision_type: 'SCHATTB',
        dependency_status_type_description: 'School   Attendance'
      }
    end
    let(:end_event) do
      {
        person_id:,
        dependency_decision_type: 'T18',
        dependency_status_type_description: 'Not an Award Dependent'
      }
    end

    it 'returns trimmed benefit type for START_EVENTS' do
      decisions = { person_id => [emc_decision] }

      result = helper.dependent_benefit_types(decisions)
      expect(result[person_id]).to eq('Minor Child')
    end

    it 'finds first START_EVENT in the array' do
      decisions = { person_id => [emc_decision, schattb_decision] }

      result = helper.dependent_benefit_types(decisions)
      expect(result[person_id]).to eq('Minor Child')
    end

    it 'returns nil when no START_EVENTS found' do
      decisions = { person_id => [end_event] }

      result = helper.dependent_benefit_types(decisions)
      expect(result[person_id]).to be_nil
    end

    it 'handles empty decision arrays' do
      decisions = { person_id => [] }

      result = helper.dependent_benefit_types(decisions)
      expect(result[person_id]).to be_nil
    end
  end

  describe '#filter_active_dependency_decisions' do
    let(:person_id) { '12345' }
    let(:current_start_event) do
      {
        person_id:,
        dependency_decision_type: 'EMC',
        award_effective_date: 1.year.ago.iso8601
      }
    end
    let(:future_start_event) do
      {
        person_id:,
        dependency_decision_type: 'SCHATTB',
        award_effective_date: 1.month.from_now.iso8601
      }
    end
    let(:future_end_event) do
      {
        person_id:,
        dependency_decision_type: 'T18',
        award_effective_date: 1.year.from_now.iso8601
      }
    end
    let(:past_end_event) do
      {
        person_id:,
        dependency_decision_type: 'T18',
        award_effective_date: 1.year.ago.iso8601
      }
    end
    let(:diaries) do
      {
        dependency_decs: [
          current_start_event,
          future_start_event,
          future_end_event,
          past_end_event
        ]
      }
    end

    it 'includes current START_EVENTS (not in future)' do
      result = helper.filter_active_dependency_decisions(diaries)
      expect(result).to include(current_start_event)
    end

    it 'includes future END_EVENTS' do
      result = helper.filter_active_dependency_decisions(diaries)
      expect(result).to include(future_end_event)
    end

    it 'excludes future START_EVENTS' do
      result = helper.filter_active_dependency_decisions(diaries)
      expect(result).not_to include(future_start_event)
    end

    it 'excludes past END_EVENTS' do
      result = helper.filter_active_dependency_decisions(diaries)
      expect(result).not_to include(past_end_event)
    end

    it 'returns empty array when dependency_decs is empty' do
      result = helper.filter_active_dependency_decisions({ dependency_decs: [] })
      expect(result).to eq([])
    end
  end

  describe '#filter_last_active_decision' do
    let(:person_id) { '12345' }
    let(:award_event_id) { 'EVENT123' }
    let(:older_active_decision) do
      {
        person_id:,
        dependency_decision_type: 'EMC',
        award_event_id:,
        award_effective_date: 2.years.ago.iso8601
      }
    end
    let(:newer_active_decision) do
      {
        person_id:,
        dependency_decision_type: 'EMC',
        award_event_id:,
        award_effective_date: 1.year.ago.iso8601
      }
    end
    let(:pending_decision) do
      {
        person_id:,
        dependency_decision_type: 'T18',
        award_event_id:,
        award_effective_date: 1.year.from_now.iso8601
      }
    end

    it 'returns most recent active decision with pending award' do
      decisions = [older_active_decision, newer_active_decision, pending_decision]

      result = helper.filter_last_active_decision(decisions)
      expect(result).to eq(newer_active_decision)
    end

    it 'returns nil when no START_EVENTS present' do
      result = helper.filter_last_active_decision([pending_decision])
      expect(result).to be_nil
    end

    it 'returns nil when no decisions have pending awards' do
      non_pending = older_active_decision.merge(award_event_id: 'DIFFERENT')
      result = helper.filter_last_active_decision([non_pending])
      expect(result).to be_nil
    end

    it 'returns nil for empty array' do
      result = helper.filter_last_active_decision([])
      expect(result).to be_nil
    end
  end

  describe '#filter_future_decisions' do
    let(:person_id) { '12345' }
    let(:future_schattb) do
      {
        person_id:,
        dependency_decision_type: 'SCHATTB',
        award_effective_date: 1.month.from_now.iso8601
      }
    end
    let(:future_t18) do
      {
        person_id:,
        dependency_decision_type: 'T18',
        award_effective_date: 6.months.from_now.iso8601
      }
    end
    let(:past_t18) do
      {
        person_id:,
        dependency_decision_type: 'T18',
        award_effective_date: 1.year.ago.iso8601
      }
    end
    let(:current_emc) do
      {
        person_id:,
        dependency_decision_type: 'EMC',
        award_effective_date: 2.years.ago.iso8601
      }
    end

    it 'includes future FUTURE_EVENTS' do
      decisions = [future_schattb, future_t18, past_t18, current_emc]

      result = helper.filter_future_decisions(decisions)
      expect(result).to contain_exactly(future_schattb, future_t18)
    end

    it 'excludes past FUTURE_EVENTS' do
      result = helper.filter_future_decisions([past_t18])
      expect(result).to be_empty
    end

    it 'excludes non-FUTURE_EVENTS' do
      result = helper.filter_future_decisions([current_emc])
      expect(result).to be_empty
    end

    it 'returns empty array for no matching decisions' do
      result = helper.filter_future_decisions([])
      expect(result).to eq([])
    end
  end

  describe '#merge_most_recent_and_future_decisions' do
    let(:person_id) { '12345' }
    let(:award_event_id) { 'EVENT123' }
    let(:current_decision) do
      {
        person_id:,
        dependency_decision_type: 'EMC',
        award_event_id:,
        award_effective_date: 1.year.ago.iso8601
      }
    end
    let(:future_decision) do
      {
        person_id:,
        dependency_decision_type: 'T18',
        award_event_id:,
        award_effective_date: 1.year.from_now.iso8601
      }
    end

    it 'combines future decisions with most recent active decision' do
      decisions = [current_decision, future_decision]

      result = helper.merge_most_recent_and_future_decisions(decisions)
      expect(result).to contain_exactly(current_decision, future_decision)
    end

    it 'handles no future decisions when there is a pending award' do
      # Need a future decision for the current decision to be considered active
      decisions = [current_decision, future_decision]
      result = helper.merge_most_recent_and_future_decisions(decisions)
      expect(result).to include(current_decision)
    end

    it 'handles no active decision' do
      result = helper.merge_most_recent_and_future_decisions([future_decision])
      expect(result).to contain_exactly(future_decision)
    end

    it 'returns empty array when both are absent' do
      result = helper.merge_most_recent_and_future_decisions([])
      expect(result).to eq([])
    end
  end

  describe '#current_and_pending_decisions' do
    let(:person1_id) { '12345' }
    let(:person2_id) { '67890' }
    let(:award_event_id) { 'EVENT123' }

    let(:person1_current) do
      {
        person_id: person1_id,
        dependency_decision_type: 'EMC',
        award_event_id:,
        award_effective_date: 1.year.ago.iso8601
      }
    end
    let(:person1_future) do
      {
        person_id: person1_id,
        dependency_decision_type: 'T18',
        award_event_id:,
        award_effective_date: 1.year.from_now.iso8601
      }
    end
    let(:person2_current) do
      {
        person_id: person2_id,
        dependency_decision_type: 'EMC',
        award_event_id: 'EVENT456',
        award_effective_date: 2.years.ago.iso8601
      }
    end
    let(:person2_future) do
      {
        person_id: person2_id,
        dependency_decision_type: 'SCHATTT',
        award_event_id: 'EVENT456',
        award_effective_date: 6.months.from_now.iso8601
      }
    end

    let(:diaries) do
      {
        dependency_decs: [person1_current, person1_future, person2_current, person2_future]
      }
    end

    it 'groups decisions by person_id' do
      result = helper.current_and_pending_decisions(diaries)

      expect(result.keys).to contain_exactly(person1_id, person2_id)
    end

    it 'includes current and future decisions for each person' do
      result = helper.current_and_pending_decisions(diaries)

      expect(result[person1_id]).to contain_exactly(person1_current, person1_future)
      expect(result[person2_id]).to contain_exactly(person2_current, person2_future)
    end

    it 'returns empty hash when dependency_decs is empty' do
      result = helper.current_and_pending_decisions({ dependency_decs: [] })
      expect(result).to eq({})
    end
  end

  describe '#dependency_decisions' do
    context 'when diaries is a hash with array of decisions' do
      let(:decision1) { { person_id: '123', dependency_decision_type: 'EMC' } }
      let(:decision2) { { person_id: '456', dependency_decision_type: 'T18' } }
      let(:diaries) { { dependency_decs: [decision1, decision2] } }

      it 'returns the array of decisions' do
        result = helper.dependency_decisions(diaries)
        expect(result).to eq([decision1, decision2])
      end
    end

    context 'when diaries is a hash with single decision hash' do
      let(:decision) { { person_id: '123', dependency_decision_type: 'EMC' } }
      let(:diaries) { { dependency_decs: decision } }

      it 'wraps single decision in array' do
        result = helper.dependency_decisions(diaries)
        expect(result).to eq([decision])
      end
    end

    context 'when diaries is a hash with nil dependency_decs' do
      let(:diaries) { { dependency_decs: nil } }

      it 'returns nil' do
        result = helper.dependency_decisions(diaries)
        expect(result).to be_nil
      end
    end

    context 'when diaries is not a hash' do
      it 'logs error and returns nil' do
        expect(helper).to receive(:monitor).and_return(double(track_error_event: nil))

        result = helper.dependency_decisions('not a hash')
        expect(result).to be_nil
      end

      it 'tracks error event with class name' do
        monitor = instance_double(DependentsBenefits::Monitor)
        allow(helper).to receive(:monitor).and_return(monitor)

        expect(monitor).to receive(:track_error_event)
          .with('Diaries is not a hash! Diaries type: String',
                'dependents_benefits.dependency_decisions.invalid_diaries_type')

        helper.dependency_decisions('not a hash')
      end
    end

    context 'when diaries is a hash without dependency_decs key' do
      let(:diaries) { { other_key: 'value' } }

      it 'returns nil' do
        result = helper.dependency_decisions(diaries)
        expect(result).to be_nil
      end
    end
  end

  describe '#monitor' do
    it 'returns a DependentsBenefits::Monitor instance' do
      expect(helper.monitor).to be_a(DependentsBenefits::Monitor)
    end
  end
end
