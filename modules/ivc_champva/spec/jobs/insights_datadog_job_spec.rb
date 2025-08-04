# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::InsightsDatadogJob, type: :job do
  let(:job) { described_class.new }
  let(:insights_service) { instance_double(IvcChampva::ProdSupportUtilities::Insights) }
  let(:mock_metrics) do
    {
      form_number: '10-10D',
      days_ago: 30,
      gate: 2,
      unique_individuals: 100,
      emails_with_multi_submits: 5,
      percentage: 5.0,
      frequency_data: {
        1 => 95,
        2 => 3,
        3 => 1,
        9 => 1
      },
      average_time_data: [
        {
          num_submissions: 9,
          avg_time_seconds: 115_781,
          avg_time_formatted: '1 days, 8 hours, 9 minutes, 41 seconds'
        },
        {
          num_submissions: 3,
          avg_time_seconds: 152_394,
          avg_time_formatted: '1 days, 18 hours, 19 minutes, 54 seconds'
        },
        {
          num_submissions: 2,
          avg_time_seconds: 285_423,
          avg_time_formatted: '3 days, 7 hours, 17 minutes, 3 seconds'
        }
      ]
    }
  end

  before do
    # Mock Settings
    ivc_forms = double('ivc_forms')
    sidekiq = double('sidekiq')

    allow(Settings).to receive(:ivc_forms).and_return(ivc_forms)
    allow(ivc_forms).to receive(:sidekiq).and_return(sidekiq)
    allow(Flipper).to receive(:enabled?).with(:champva_insights_datadog_job).and_return(true)

    # Mock the insights service
    allow(IvcChampva::ProdSupportUtilities::Insights).to receive(:new).and_return(insights_service)
    allow(insights_service).to receive(:gather_submission_metrics).and_return(mock_metrics)

    # Mock StatsD and Rails.logger
    allow(StatsD).to receive(:gauge)
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    context 'when the job is enabled' do
      it 'calls the insights service with default parameters' do
        job.perform

        expect(insights_service).to have_received(:gather_submission_metrics).with(30, 2, '10-10D')
      end

      it 'calls the insights service with custom parameters' do
        job.perform(days_ago: 7, gate: 3, form_number: '10-7959C')

        expect(insights_service).to have_received(:gather_submission_metrics).with(7, 3, '10-7959C')
      end

      it 'publishes basic metrics to StatsD' do
        job.perform

        base_tags = ['form_number:10-10D', 'days_ago:30', 'gate:2']
        expect(StatsD).to have_received(:gauge).with('ivc_champva.insights.unique_individuals', 100, tags: base_tags)
        expect(StatsD).to have_received(:gauge).with('ivc_champva.insights.multi_submitters', 5, tags: base_tags)
        expect(StatsD).to have_received(:gauge).with(
          'ivc_champva.insights.multi_submission_percentage',
          5.0,
          tags: base_tags
        )
      end

      it 'publishes frequency metrics to StatsD' do
        job.perform

        expect(StatsD).to have_received(:gauge).with(
          'ivc_champva.insights.frequency.users_with_submissions',
          95,
          tags: ['form_number:10-10D', 'submission_count:1']
        )
        expect(StatsD).to have_received(:gauge).with(
          'ivc_champva.insights.frequency.users_with_submissions',
          3,
          tags: ['form_number:10-10D', 'submission_count:2']
        )
        expect(StatsD).to have_received(:gauge).with(
          'ivc_champva.insights.frequency.users_with_submissions',
          1,
          tags: ['form_number:10-10D', 'submission_count:9']
        )
      end

      it 'publishes timing metrics to StatsD' do
        job.perform

        # Check for 9 submissions timing
        expect(StatsD).to have_received(:gauge).with(
          'ivc_champva.insights.timing.avg_seconds_between_resubmissions',
          115_781,
          tags: ['form_number:10-10D', 'submission_count:9']
        )
        expect(StatsD).to have_received(:gauge).with(
          'ivc_champva.insights.timing.avg_hours_between_resubmissions',
          32.16,
          tags: ['form_number:10-10D', 'submission_count:9']
        )

        # Check for 2 submissions timing
        expect(StatsD).to have_received(:gauge).with(
          'ivc_champva.insights.timing.avg_seconds_between_resubmissions',
          285_423,
          tags: ['form_number:10-10D', 'submission_count:2']
        )
        expect(StatsD).to have_received(:gauge).with(
          'ivc_champva.insights.timing.avg_hours_between_resubmissions',
          79.28,
          tags: ['form_number:10-10D', 'submission_count:2']
        )
      end

      it 'skips timing metrics when avg_time_seconds is nil' do
        mock_metrics[:average_time_data] = [
          {
            num_submissions: 2,
            avg_time_seconds: nil,
            avg_time_formatted: nil
          }
        ]

        job.perform

        expect(StatsD).not_to have_received(:gauge).with(
          'ivc_champva.insights.timing.avg_seconds_between_resubmissions',
          anything,
          tags: ['form_number:10-10D', 'submission_count:2']
        )
      end

      it 'logs successful completion' do
        job.perform

        expect(Rails.logger).to have_received(:info).with(
          'InsightsDatadogJob completed for 10-10D - 100 users analyzed'
        )
        expect(Rails.logger).to have_received(:info).with(
          'Insights metrics for 10-10D: 100 unique users, 5 multi-submitters (5.0%)'
        )
      end
    end

    context 'when the job is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_insights_datadog_job).and_return(false)
      end

      it 'does not execute the job logic' do
        job.perform

        expect(insights_service).not_to have_received(:gather_submission_metrics)
        expect(StatsD).not_to have_received(:gauge)
      end
    end

    context 'when an error occurs' do
      let(:error_message) { 'Database connection failed' }

      before do
        allow(insights_service).to receive(:gather_submission_metrics).and_raise(StandardError, error_message)
      end

      it 'logs the error and increments failure metric' do
        expect { job.perform }.to raise_error(StandardError, error_message)

        expect(Rails.logger).to have_received(:error).with("InsightsDatadogJob failed: #{error_message}")
        expect(StatsD).to have_received(:increment).with(
          'ivc_champva.insights.job_failure',
          tags: ['form_number:10-10D']
        )
      end

      it 'includes form_number in failure metric tags when provided' do
        expect { job.perform(form_number: '10-7959C') }.to raise_error(StandardError)

        expect(StatsD).to have_received(:increment).with(
          'ivc_champva.insights.job_failure',
          tags: ['form_number:10-7959C']
        )
      end
    end
  end

  describe 'constants' do
    it 'has the correct default values' do
      expect(described_class::STATSD_PREFIX).to eq('ivc_champva.insights')
      expect(described_class::DEFAULT_DAYS_AGO).to eq(30)
      expect(described_class::DEFAULT_GATE).to eq(2)
    end
  end
end
