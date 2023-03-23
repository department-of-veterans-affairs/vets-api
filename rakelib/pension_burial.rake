# frozen_string_literal: true

namespace :pension_burial do
  desc 'retry failed pension burial jobs'
  task retry_jobs: :environment do
    # JIDS up to date as of Dec 4, 2017 2:40:39 PM UTC
    # TODO: might need to run this again if all these jobs haven't failed yet
    JIDS = %w[bb2894d2445beeaaf8c0e28d fe0a9e359d0f61b0766c7ef4 b893a455044bfc5b46dae93e].freeze
    Rails.application.eager_load!

    Sidekiq::DeadSet.new.each do |job|
      jid = job.jid

      if JIDS.include?(jid)
        guid = job.args[1]['internal']['history'][0]['user_args']['guid']
        persistent_attachment = PersistentAttachment.find_by(guid:)
        raise if persistent_attachment.completed_at.present?

        persistent_attachment.process
        puts "#{jid} rerun"
      end
    end
  end

  desc 'Delete old claims'
  task delete_pre_central_mail: :environment do
    Rails.application.eager_load!
    scs = SavedClaim.where(type: ['SavedClaim::Burial', 'SavedClaim::Pension']).where(
      'created_at < ?', Date.parse('2018-04-01')
    )

    scs.find_each do |sc|
      sc.persistent_attachments.delete_all
    end

    scs.delete_all
  end
end
