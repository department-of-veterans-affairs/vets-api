# frozen_string_literal: true
desc 'retry failed pension burial jobs'
task pension_burial_retry_jobs: :environment do
  Rails.application.eager_load!
  DATESTAMP_FIRST_ERROR = Time.zone.parse('2017-08-18T19:49:00+00:00')
  GENERATE_CLAIM_FIRST_ERROR = Time.zone.parse('2017-10-09T00:48:17+00:00')
  WRAPPED_CLASS = 'Workflow::Task::Shared::DatestampPdfTask'

  Sidekiq::DeadSet.new.each do |job|
    created_at = DateTime.strptime(job['created_at'].to_s, '%s')
    args = job.args
    jid = job.jid

    if job.klass == 'GenerateClaimPDFJob'
      if created_at >= GENERATE_CLAIM_FIRST_ERROR
        GenerateClaimPDFJob.perform_async(*args)
        puts "GenerateClaimPDFJob rerun #{jid}"
      end
    elsif job['wrapped'] == WRAPPED_CLASS
      if created_at >= DATESTAMP_FIRST_ERROR
        args[1].deep_symbolize_keys!
        Workflow::Runner.perform_async(*args)
        puts "#{WRAPPED_CLASS} rerun #{jid}"
      end
    end
  end
end
