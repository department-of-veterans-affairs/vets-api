# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form526NewConditionsStateSnapshotJob, type: :worker do
  before do
    Sidekiq::Job.clear_all
    allow(Flipper).to receive(:enabled?).and_call_original
  end

  describe 'new conditions workflow state logging' do
    let!(:v2_in_progress_form) do
      ipf = create(:in_progress_form, form_id: '21-526EZ')
      ipf.update(metadata: { 'new_conditions_workflow' => true })
      ipf
    end

    let!(:v1_in_progress_form) do
      create(:in_progress_form, form_id: '21-526EZ')
    end

    let!(:v1_form_with_false) do
      ipf = create(:in_progress_form, form_id: '21-526EZ')
      ipf.update(metadata: { 'new_conditions_workflow' => false })
      ipf
    end

    let!(:other_form) do
      create(:in_progress_form, form_id: '22-1990')
    end

    describe '#perform' do
      context 'when feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:disability_compensation_new_conditions_stats_job).and_return(false)
        end

        it 'logs that the job is disabled and does not send metrics' do
          expect(Rails.logger).to receive(:info).with(
            'New conditions state snapshot job disabled',
            hash_including(message: 'Flipper flag disability_compensation_new_conditions_stats_job is disabled')
          )
          expect(StatsD).not_to receive(:gauge)

          described_class.new.perform
        end
      end

      context 'when feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:disability_compensation_new_conditions_stats_job).and_return(true)
        end

        it 'sends metrics to StatsD' do
          prefix = described_class::STATSD_PREFIX

          expect(StatsD).to receive(:gauge).with("#{prefix}.v2_in_progress_forms_count", 1)
          expect(StatsD).to receive(:gauge).with("#{prefix}.v1_in_progress_forms_count", 2)
          expect(StatsD).to receive(:gauge).with("#{prefix}.total_in_progress_forms_count", 3)

          described_class.new.perform
        end
      end

      context 'when an error occurs' do
        before do
          allow(Flipper).to receive(:enabled?).with(:disability_compensation_new_conditions_stats_job).and_return(true)
          allow(InProgressForm).to receive(:where).and_raise(StandardError.new('Database error'))
        end

        it 'logs the error and does not raise' do
          expect(Rails.logger).to receive(:error).with(
            'Error logging new conditions state snapshot',
            hash_including(message: 'Database error')
          )

          expect { described_class.new.perform }.not_to raise_error
        end
      end
    end

    describe '#v2_in_progress_forms' do
      before do
        allow(Flipper).to receive(:enabled?).with(:disability_compensation_new_conditions_stats_job).and_return(true)
      end

      it 'returns only forms with new_conditions_workflow metadata set to true' do
        job = described_class.new
        result = job.send(:v2_in_progress_forms)

        expect(result).to include(v2_in_progress_form.id)
        expect(result).not_to include(v1_in_progress_form.id)
        expect(result).not_to include(other_form.id)
      end
    end

    describe '#v1_in_progress_forms' do
      before do
        allow(Flipper).to receive(:enabled?).with(:disability_compensation_new_conditions_stats_job).and_return(true)
      end

      it 'returns 526 forms where new_conditions_workflow is not true' do
        job = described_class.new
        result = job.send(:v1_in_progress_forms)

        expect(result).to include(v1_in_progress_form.id)
        expect(result).to include(v1_form_with_false.id)
        expect(result).not_to include(v2_in_progress_form.id)
        expect(result).not_to include(other_form.id)
      end
    end

    describe '#total_in_progress_forms' do
      before do
        allow(Flipper).to receive(:enabled?).with(:disability_compensation_new_conditions_stats_job).and_return(true)
      end

      it 'returns all 526 in-progress forms regardless of workflow version' do
        job = described_class.new
        result = job.send(:total_in_progress_forms)

        expect(result).to include(v2_in_progress_form.id)
        expect(result).to include(v1_in_progress_form.id)
        expect(result).to include(v1_form_with_false.id)
        expect(result).not_to include(other_form.id)
      end
    end
  end
end
