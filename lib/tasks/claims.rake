# frozen_string_literal: true

namespace :claims do
  FORM_IDS = [
    '21P-527EZ',  # Pension
    '21P-530',    # Burial
  ].freeze

  desc 'Find failed burial and pension claim uploads'
  task failed: :environment do
    PersistentAttachment.where('created_at < ?', 21.days.ago).find_by(form_id: FORM_IDS, completed_at: nil)
  end
end
