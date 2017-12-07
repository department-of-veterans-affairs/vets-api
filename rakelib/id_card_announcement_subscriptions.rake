# frozen_string_literal: true

namespace :id_card_announcement_subscriptions do
  desc 'Export distinct email addresses'
  task export: :environment do
    emails = IdCardAnnouncementSubscription.pluck(:email)
    puts emails.join("\n")
  end

  desc 'Export report'
  task report: :environment do
    ActiveRecord::Base.connection.execute 'set statement_timeout to 60000'

    email_count = IdCardAnnouncementSubscription.count
    va_email_count = IdCardAnnouncementSubscription.where("split_part(email, '@', 2) = 'va.gov'").count

    printf "%-20s %d\n" % ['Email Count:', email_count]
    printf "%-20s %d\n" % ['VA Email Count:', va_email_count]
  end
end
