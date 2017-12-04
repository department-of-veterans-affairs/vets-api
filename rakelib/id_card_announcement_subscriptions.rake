# frozen_string_literal: true

namespace :id_card_announcement_subscriptions do
  desc 'Export distinct email addresses'
  task export: :environment do
    emails = IdCardAnnouncementSubscription.pluck(:email)
    puts emails.join("\n")
  end
end
