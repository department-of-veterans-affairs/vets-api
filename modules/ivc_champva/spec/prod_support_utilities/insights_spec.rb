# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::ProdSupportUtilities::Insights, type: :service do
  let(:insights) { described_class.new }
  let(:mock_submissions_data) do
    # Create mock data with 100 total users for test setup:
    # 95 with 1 submission, 3 with 2, 1 with 3, 1 with 5
    submissions = {}

    # 95 users with 1 submission
    (1..95).each { |i| submissions["user#{i}@email.com"] = 1 }

    # 3 users with 2 submissions
    (96..98).each { |i| submissions["user#{i}@email.com"] = 2 }

    # 1 user with 3 submissions
    submissions['user99@email.com'] = 3

    # 1 user with 5 submissions
    submissions['user100@email.com'] = 5

    submissions
  end

  before do
    # Mock the database query
    allow(insights).to receive(:get_submissions_by_email).and_return(mock_submissions_data)

    # Mock the average time calculations to return expected durations in seconds
    average_times = {
      2 => 285_423, # 3 days, 7 hours, 17 minutes, 3 seconds
      3 => 152_394, # 1 days, 18 hours, 19 minutes, 54 seconds
      5 => 115_781  # 1 days, 8 hours, 9 minutes, 41 seconds
    }

    allow(insights).to receive(:average_time_between_resubmissions) do |_, _, _, num_submissions, _|
      average_times[num_submissions]
    end
  end

  describe '#count_batches_by_email_grouped' do
    it 'prints the expected console output' do
      basic_stats_regex = Regexp.new(
        '10-10D submits over the last 30 days:.*' \
        '100 unique email addresses.*' \
        '5 unique email addresses associated with repeat submissions.*' \
        '5\.0% of submitters have 2 or more submissions',
        Regexp::MULTILINE
      )
      expect { insights.count_batches_by_email_grouped(30, 2, '10-10D') }.to output(basic_stats_regex).to_stdout

      frequency_regex = Regexp.new(
        'Number of users with 5 submissions: 1.*' \
        'Number of users with 3 submissions: 1.*' \
        'Number of users with 2 submissions: 3',
        Regexp::MULTILINE
      )
      expect { insights.count_batches_by_email_grouped(30, 2, '10-10D') }.to output(frequency_regex).to_stdout

      timing_regex = Regexp.new(
        'Avg time between resubmits for users with 5 submissions: 1 days, 8 hours, 9 minutes, 41 seconds.*' \
        'Avg time between resubmits for users with 3 submissions: 1 days, 18 hours, 19 minutes, 54 seconds.*' \
        'Avg time between resubmits for users with 2 submissions: 3 days, 7 hours, 17 minutes, 3 seconds',
        Regexp::MULTILINE
      )
      expect { insights.count_batches_by_email_grouped(30, 2, '10-10D') }.to output(timing_regex).to_stdout
    end
  end

  describe '#gather_submission_metrics' do
    let(:result) { insights.gather_submission_metrics(30, 2, '10-10D') }

    it 'returns the expected data structure' do
      expect(result).to be_a(Hash)
      expect(result[:form_number]).to eq('10-10D')
      expect(result[:days_ago]).to eq(30)
      expect(result[:gate]).to eq(2)
    end

    it 'returns correct basic statistics' do
      expect(result[:unique_individuals]).to eq(100)
      expect(result[:emails_with_multi_submits]).to eq(5)
      expect(result[:percentage]).to eq(5.0)
    end

    it 'returns correct frequency data' do
      frequency = result[:frequency_data]
      expect(frequency[5]).to eq(1)
      expect(frequency[3]).to eq(1)
      expect(frequency[2]).to eq(3)
      expect(frequency[1]).to eq(95)
    end

    it 'returns correct average time data structure' do
      avg_times = result[:average_time_data]
      expect(avg_times).to be_an(Array)
      expect(avg_times.length).to eq(3) # Should have entries for 2, 3, and 5 submissions

      # Find the entry for 5 submissions
      five_submits = avg_times.find { |data| data[:num_submissions] == 5 }
      expect(five_submits[:avg_time_seconds]).to eq(115_781)
      expect(five_submits[:avg_time_formatted]).to eq('1 days, 8 hours, 9 minutes, 41 seconds')

      # Find the entry for 3 submissions
      three_submits = avg_times.find { |data| data[:num_submissions] == 3 }
      expect(three_submits[:avg_time_seconds]).to eq(152_394)
      expect(three_submits[:avg_time_formatted]).to eq('1 days, 18 hours, 19 minutes, 54 seconds')

      # Find the entry for 2 submissions
      two_submits = avg_times.find { |data| data[:num_submissions] == 2 }
      expect(two_submits[:avg_time_seconds]).to eq(285_423)
      expect(two_submits[:avg_time_formatted]).to eq('3 days, 7 hours, 17 minutes, 3 seconds')
    end

    it 'includes submissions_by_email data' do
      expect(result[:submissions_by_email]).to eq(mock_submissions_data)
    end
  end
end
