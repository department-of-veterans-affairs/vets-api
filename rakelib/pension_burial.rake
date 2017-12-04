# frozen_string_literal: true
desc 'retry failed pension burial jobs'
task pension_burial_retry_jobs: :environment do
  # JIDS up to date as of Dec 4, 2017 2:40:39 PM UTC
  JIDS = %w(bb2894d2445beeaaf8c0e28d fe0a9e359d0f61b0766c7ef4 b893a455044bfc5b46dae93e 6c055d058d1682acc7ee28a9).freeze
  Rails.application.eager_load!

  Sidekiq::DeadSet.new.each do |job|
    jid = job.jid

    if JIDS.include?(jid)
      guid = job.args[1]['internal']['history'][0]['user_args']['guid']
      persistent_attachment = PersistentAttachment.find_by(guid: guid)
      raise if persistent_attachment.completed_at.present?
      persistent_attachment.process
      puts "#{jid} rerun"
    end
  end
end
