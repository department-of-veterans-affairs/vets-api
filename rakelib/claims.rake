# frozen_string_literal: true

namespace :claims do
  FORM_IDS = [
    '21P-527EZ', # Pension form
    '21P-530EZ' # Burial form
  ].freeze

  COLUMNS = %i[
    form_id
    created_at
    updated_at
    guid
  ].freeze

  desc 'Find failed burial and pension claim uploads'
  task failed: :environment do
    failed_uploads = PersistentAttachment.where(form_id: %w[21P-527EZ 21P-530EZ], completed_at: nil)
                                         .where('created_at < ?', 21.days.ago)
                                         .order(:created_at)

    rows = [COLUMNS]
    failed_uploads.each do |upload|
      rows << COLUMNS.map { |col| upload[col] }
    end

    puts rows.map(&:to_csv).join
  end
end
