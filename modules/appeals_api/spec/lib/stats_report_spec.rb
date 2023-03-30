# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/stats_report'

describe AppealsApi::StatsReport do
  def create_transition_group
    [
      create(:higher_level_review_v2),
      create(:notice_of_disagreement_v2),
      create(:supplemental_claim)
    ]
  end

  def create_transition_groups(group_size: 1, num_groups: described_class::STATUS_TRANSITION_PAIRS.count)
    num_groups.times.map { group_size.times.map { create_transition_group }.flatten }
  end

  let(:end_date) { Time.utc(2022, 3, 4, 5, 6, 7) }
  let(:start_date) { end_date - 1.month }
  let(:report) { described_class.new(start_date, end_date) }
  let(:starting_statuses) { described_class::STATUS_TRANSITION_PAIRS.collect(&:first).uniq }
  let(:stalled_groups) { create_transition_groups(num_groups: starting_statuses.count, group_size: 4) }
  let(:short_timespan_groups) { create_transition_groups(group_size: 3) }
  let(:long_timespan_groups) { create_transition_groups }
  let(:outside_range_groups) { create_transition_groups }

  before do
    Sidekiq::Testing.inline! do
      # Create statuses to support lists of stalled records:
      oldest_date = end_date - described_class::STALLED_RECORD_MONTHS.last.months - 2.weeks
      Timecop.freeze(oldest_date)
      starting_statuses.each_with_index do |status, i|
        stalled_groups[i].each_with_index do |r, j|
          r.update_status!(status:)
          Timecop.travel(oldest_date + (i + j + 1).weeks)
        end
      end

      # Create statuses to support transition timespan stats:
      described_class::STATUS_TRANSITION_PAIRS.each_with_index do |(status_from, status_to), i|
        # These records should all be included in the report:
        (short_timespan_groups[i] + long_timespan_groups[i]).each do |record|
          Timecop.travel(start_date - 1.day)
          record.update_status!(status: status_from)
        end

        # Make most of the status transitions around the same timespan:
        short_timespan_groups[i].each_with_index do |record, j|
          Timecop.travel(start_date + i.days + j.hours)
          record.update_status!(status: status_to)
        end

        # Make a few timespans longer to differentiate the mean:
        Timecop.travel(end_date - 1.day)
        long_timespan_groups[i].each do |record|
          record.update_status!(status: status_to)
        end

        # These records should not be included:
        Timecop.travel(start_date - 1.week)
        outside_range_groups[i].each { |r| r.update_status!(status: status_from) }
        Timecop.travel(start_date - 1.day)
        outside_range_groups[i].each { |r| r.update_status!(status: status_to) }
      end
    end
  end

  after do
    Timecop.return
  end

  describe 'private methods' do
    let(:status_from) { described_class::STATUS_TRANSITION_PAIRS.first[0] }
    let(:status_to) { described_class::STATUS_TRANSITION_PAIRS.first[1] }
    let(:statusable_type) { AppealsApi::HigherLevelReview.name }

    describe '#status_update_records' do
      let(:expected_appeals) do
        (short_timespan_groups.first + long_timespan_groups.first).filter do |r|
          r.instance_of? AppealsApi::HigherLevelReview
        end
      end

      it "finds pairs of updates that match the given from/to statuses and end within the report's timespan" do
        status_update_pairs = report.send(:status_update_records, statusable_type, status_from, status_to)
        expect(status_update_pairs.count).to eq(expected_appeals.count)
        status_update_pairs.each do |(status, prev_status)|
          expect(expected_appeals.pluck(:id)).to include(status.statusable_id)
          expect(status.statusable_id).to eq(prev_status.statusable_id)
          expect(status.from).to eq(status_from)
          expect(status.to).to eq(status_to)
          expect(prev_status.to).to eq(status_from)
        end
      end
    end

    describe '#stats' do
      it 'finds the mean and median timespan between the given pairs of status update records' do
        result = report.send(:stats, report.send(:status_update_records, statusable_type, status_from, status_to))
        expect(result[:mean]).to eq(677_700)
        expect(result[:median]).to eq(102_600)
      end

      it 'returns nil data when no status update pairs are given' do
        result = report.send(:stats, [])
        expect(result[:mean]).to be_nil
        expect(result[:median]).to be_nil
      end
    end

    describe '#stalled_records' do
      let(:status) { starting_statuses.first }
      let(:stalled_records_in_status) do
        stalled_groups.first.filter { |r| r.instance_of? AppealsApi::HigherLevelReview }
      end

      it 'finds records which have remained in the given status for longer than the stalled threshold' do
        records = report.send(:stalled_records, AppealsApi::HigherLevelReview, status)
        expect(records.pluck(:id)).to match_array(stalled_records_in_status.pluck(:id))
        expect(records).to all(have_attributes(
                                 {
                                   status:,
                                   updated_at: be < end_date - described_class::STALLED_RECORD_MONTHS.first.months
                                 }
                               ))
      end
    end
  end

  describe '#text' do
    let(:text) { report.text }
    let(:expected_means_medians) do
      [
        [ # Higher Level Reviews
          ['7d 20h 15m', '1d 4h 30m'],
          ['8d 14h 15m', '2d 4h 30m'],
          ['9d 8h 15m', '3d 4h 30m'],
          ['10d 2h 15m', '4d 4h 30m']
        ],
        [ # Notice of Disagreements
          ['7d 21h 0m', '1d 5h 30m'],
          ['8d 15h 0m', '2d 5h 30m'],
          ['9d 9h 0m', '3d 5h 30m'],
          ['10d 3h 0m', '4d 5h 30m']
        ],
        [ # Supplemental Claims
          ['7d 21h 45m', '1d 6h 30m'],
          ['8d 15h 45m', '2d 6h 30m'],
          ['9d 9h 45m', '3d 6h 30m'],
          ['10d 3h 45m', '4d 6h 30m']
        ]
      ]
    end

    it 'includes the start and end dates' do
      expect(text).to match(/Feb 4, 2022 to Mar 4, 2022/)
    end

    it 'includes stats for status transitions where data was found' do
      expected_means_medians.each do |expected_mean_median|
        described_class::STATUS_TRANSITION_PAIRS.each_with_index do |(status_from, status_to), i|
          mean, median = expected_mean_median[i]
          expect(text).to match(/From '#{status_from}' to '#{status_to}':\n\* Average: #{mean}\n\* Median:  #{median}/)
        end
      end
    end

    it 'includes lists of stalled records for each appeal type' do
      expect(text.scan(/Stalled in 'processing':/).count).to eq(3)
    end

    it 'includes lists of stalled records for each starting state' do
      expect(text).to match(/Stalled in 'processing':\n\* 4-5 months: 1\n\* 5-6 months: 2\n\* > 6 months: 1/)
      expect(text).to match(/Stalled in 'submitted':\n\* 3-4 months: 1\n\* 4-5 months: 2\n\* 5-6 months: 1/)
      expect(text).to match(/Stalled in 'error':\n\* 3-4 months: 2\n\* 4-5 months: 1\n\* 5-6 months: 1/)
    end

    context 'when there is no data' do
      let(:report) { described_class.new(1.year.ago, 1.year.ago - 1.week) }

      it 'includes empty stats for status transitions where no data was found' do
        expect(text).to match(/From 'processing' to 'submitted':\n\* Average: \(none\)\n\* Median:  \(none\)/)
      end

      it 'Omits empty lists for stalled records' do
        expect(text).to match(/### Stalled records\n\n\(none\)/)
        expect(text).not_to match(/Stalled in '.*'/)
      end
    end
  end
end
