# frozen_string_literal: true

namespace :id_card_announcement_subscriptions do
  # Example: To export the second set of 100 non-VA emails, provide offset=100
  # $ rake id_card_announcement_subscriptions:export_non_va[100]
  desc 'Export distinct email addresses'
  task :export_non_va, %i[offset limit] => [:environment] do |_, args|
    offset = (args[:offset] || 0).to_i
    limit = (args[:limit] || 100).to_i
    emails = IdCardAnnouncementSubscription.non_va.offset(offset)
                                           .limit(limit)
                                           .order(:created_at)
                                           .pluck(:email)

    puts emails.join("\n")
  end

  # Example: To export 50 VA emails after 200 have already been processed:
  # $ rake id_card_announcement_subscriptions:export_va[200,50]
  desc 'Export distinct VA email addresses'
  task :export_va, %i[offset limit] => [:environment] do |_, args|
    offset = (args[:offset] || 0).to_i
    limit = (args[:limit] || 100).to_i
    emails = IdCardAnnouncementSubscription.va.offset(offset)
                                           .limit(limit)
                                           .order(:created_at)
                                           .pluck(:email)

    puts emails.join("\n")
  end

  desc 'Export report'
  task report: :environment do
    ActiveRecord::Base.connection.execute 'set statement_timeout to 60000'

    email_count = IdCardAnnouncementSubscription.count
    va_email_count = IdCardAnnouncementSubscription.va.count

    printf "%-20s %d\n", 'Email Count:', email_count
    printf "%-20s %d\n", 'VA Email Count:', va_email_count
  end
end
