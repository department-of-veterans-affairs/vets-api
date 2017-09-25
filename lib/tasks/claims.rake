# frozen_string_literal: true

namespace :claims do
  FORM_IDS = [
    '21P-527EZ',
    '21P-530'
  ].freeze

  desc 'TODO'
  task failed: :environment do
    # PersistentAttachment.where('created_at < ?', 7.days.ago).find_by(form_id: FORM_IDS, completed_at: nil)
    PersistentAttachment.find_by(form_id: FORM_IDS, completed_at: nil)
  end
end
