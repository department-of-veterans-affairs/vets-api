# frozen_string_literal: true
desc 'retry failed pension burial jobs'
task pension_burial_retry_jobs: :environment do
  FIRST_ERROR_TIME = Time.utc(2017, 9, 16)
  WRAPPED_CLASS = 'Workflow::Task::Shared::DatestampPdfTask'

  Sidekiq::DeadSet.new.each do |job|
    if job['wrapped'] == WRAPPED_CLASS
      failed_at = DateTime.strptime(job['failed_at'].to_s, '%s')

      Workflow::Runner.perform_async(*job.args) if failed_at >= FIRST_ERROR_TIME
    end
  end
end
