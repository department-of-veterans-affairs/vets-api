# frozen_string_literal: true

require 'rails_helper'
require 'fugit'

RSpec.describe CovidVaccine::ScheduledBatchJob, type: :worker do
  describe 'schedule' do
    sidekiq_file = Rails.root.join('config', 'sidekiq_scheduler.yml')
    schedule = YAML.load_file(sidekiq_file)['CovidVaccine::ScheduledBatchJob']
    let(:parsed_schedule) { Fugit.do_parse(schedule['cron']) }

    it 'has a job class' do
      expect { schedule['class'].constantize }.not_to raise_error
    end

    it 'is scheduled in the eastern time zone' do
      expect(parsed_schedule.zone).to eq('America/New_York')
    end

    it 'is scheduled to run every 15 min' do
      expect(parsed_schedule.minutes).to eq([0, 15, 30, 45])
    end
  end

  describe '#perform' do
    context 'when batch creation succeeds' do
      let(:batch_id) { '20210101123456' }

      before { allow(CovidVaccine::V0::EnrollmentProcessor).to receive(:batch_records!).and_return(batch_id) }

      context 'when the enrollment job is enabled' do
        it 'enqueues a CovidVaccine::EnrollmentUploadJob job' do
          with_settings(
            Settings.covid_vaccine.enrollment_service, { job_enabled: true }
          ) do
            expect { subject.perform }.to change(CovidVaccine::EnrollmentUploadJob.jobs, :size).by(1)
          end
        end

        # temporarily disabling this spec sometimes fails on CI
        xit 'logs its progress including an enrollment jid' do
          with_settings(
            Settings.covid_vaccine.enrollment_service, { job_enabled: true }
          ) do
            expect(Rails.logger).to receive(:info).with('Covid_Vaccine Scheduled_Batch: Start')
            expect(Rails.logger).to receive(:info).with('Covid_Vaccine Scheduled_Batch: Batch_Created',
                                                        batch_id:)
            expect(Rails.logger).to receive(:info).with(
              'Covid_Vaccine Scheduled_Batch: Success', batch_id:, enrollment_upload_job_id: /\S{24}/
            )

            expect { subject.perform }
              .to trigger_statsd_increment('shared.sidekiq.default.CovidVaccine_EnrollmentUploadJob.enqueue')
              .and trigger_statsd_increment('worker.covid_vaccine_schedule_batch.success')
          end
        end
      end

      context 'when the enrollment job is disabled' do
        it 'logs its progress without an enrollment jid' do
          with_settings(
            Settings.covid_vaccine.enrollment_service, { job_enabled: false }
          ) do
            expect(Rails.logger).to receive(:info).with('Covid_Vaccine Scheduled_Batch: Start')
            expect(Rails.logger).to receive(:info).with('Covid_Vaccine Scheduled_Batch: Batch_Created',
                                                        batch_id:)
            expect(Rails.logger).to receive(:info).with(
              'Covid_Vaccine Scheduled_Batch: Success', { batch_id: }
            )

            expect(StatsD).to receive(:increment).once.with('worker.covid_vaccine_schedule_batch.success')

            subject.perform
          end
        end

        it 'does not enqueues a CovidVaccine::EnrollmentUploadJob job' do
          with_settings(
            Settings.covid_vaccine.enrollment_service, { job_enabled: false }
          ) do
            expect { subject.perform }.to change(CovidVaccine::EnrollmentUploadJob.jobs, :size).by(0)
          end
        end
      end
    end

    context 'when batch creation fails' do
      before do
        allow(CovidVaccine::V0::EnrollmentProcessor).to receive(:batch_records!).and_raise(
          ActiveRecord::ActiveRecordError
        )
      end

      it 'does not enqueues a CovidVaccine::EnrollmentUploadJob job' do
        expect { subject.perform }.to raise_error(ActiveRecord::ActiveRecordError)
        expect(CovidVaccine::EnrollmentUploadJob.jobs.size).to eq(0)
      end

      it 'logs its progress and raises the original error' do
        expect(Rails.logger).to receive(:info).with('Covid_Vaccine Scheduled_Batch: Start')
        expect(Rails.logger).to receive(:error).with('Covid_Vaccine Scheduled_Batch: Failed').ordered.and_call_original
        expect(Rails.logger).to receive(:error).at_least(:once).with(instance_of(String)).ordered # backtrace line

        expect(StatsD).to receive(:increment).once.with('worker.covid_vaccine_schedule_batch.error')

        expect { subject.perform }.to raise_error(ActiveRecord::ActiveRecordError)
      end
    end
  end
end
