# frozen_string_literal: true
desc 'retry failed evss jobs'
task evss_retry_jobs: :environment do
  RELEASE_TIME = Time.zone.parse('2017-09-20T21:59:58.486Z')
  ERROR_CLASS = 'Aws::S3::Errors::NoSuchKey'

  Sidekiq::DeadSet.new.each do |job|
    if job.klass == 'EVSS::DocumentUpload'
      created_at = DateTime.strptime(job['created_at'].to_s, '%s')

      if created_at >= RELEASE_TIME && job['error_class'] == ERROR_CLASS
        EVSS::DocumentUpload.perform_async(*job.args)
        job.delete
      end
    end
  end
end
