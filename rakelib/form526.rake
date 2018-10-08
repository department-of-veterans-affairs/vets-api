# frozen_string_literal: true

require 'pp'

namespace :form526 do
  desc 'Get all jobs within a date period. [<start date>,<end date>]'
  task :jobs, %i[start_date end_date] => [:environment] do |_, args|
    def print_row(created_at, updated_at, job_id, status)
      printf "%-24s %-24s %-25s %s\n", created_at, updated_at, job_id, status
    end

    TRXS = AsyncTransaction::EVSS::VA526ezSubmitTransaction

    start_date = args[:start_date] || 30.days.ago.utc.to_s
    end_date = args[:end_date] || Time.zone.now.utc.to_s

    print_row('created at:', 'updated at:', 'job id:', 'job status:')
    TRXS.where('created_at BETWEEN ? AND ?', start_date, end_date)
        .order(created_at: :desc)
        .find_each do |job|
      print_row(job.created_at, job.updated_at, job.transaction_id, job.transaction_status)
    end
  end

  desc 'Get job details given a job id'
  task :job, %i[job_id] => [:environment] do |_, args|
    raise 'No job id provided' unless args[:job_id]

    job = AsyncTransaction::EVSS::VA526ezSubmitTransaction.where(transaction_id: args[:job_id]).first

    form = JSON.parse(job.saved_claim.form)
    form['form526']['veteran'] = 'OMITTED'

    puts '----------------------------------------'
    puts 'Job Details:'
    puts "user uuid: #{job.user_uuid}"
    puts "source id: #{job.source_id}"
    puts "source: #{job.source}"
    puts "transaction status: #{job.transaction_status}"
    puts "created at: #{job.created_at}"
    puts "updated at: #{job.updated_at}"
    puts '----------------------------------------'
    puts 'Job Metadata:'
    puts job.metadata
    puts '----------------------------------------'
    puts 'Form Data:'
    puts JSON.pretty_generate(form)
  end
end
