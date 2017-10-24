module EVSS
  module RetryJobs
    module_function

    def run
      release_time = Time.parse('2017-09-20T21:59:58.486Z')

      Sidekiq::DeadSet.new.each do |job|
        if job.klass == 'EVSS::DocumentUpload'
          created_at = DateTime.strptime(job['created_at'].to_s, '%s')

          if created_at >= release_time
            EVSS::DocumentUpload.perform_async(*job.args)
            job.delete
          end
        end
      end
    end
  end
end
