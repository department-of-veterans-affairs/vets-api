# frozen_string_literal: true

namespace :claims do
  FORM_IDS = [
    '21P-527EZ',  # Pension
    '21P-530',    # Burial
  ].freeze

  def print_row(args)
    printf "%-16s %-16s %-16s %-16s %s\n", *args
  end

  def print_header
    print_row ['FORM TYPE', 'CREATED', 'UPDATED', 'COMPLETED', 'GUID']
  end

  def print_failed_upload(upload)
    print_row [upload.form_id, upload.created_at, upload.updated_at, upload.completed_at, upload.guid]
  end

  desc 'Find failed burial and pension claim uploads'
  task failed: :environment do
    failed_uploads = PersistentAttachment.where('created_at < ?', 21.days.ago)
                                         .where(form_id: FORM_IDS)
                                         .where(completed_at: nil)

    print_header

    if failed_uploads.present?
      uploads.each do |upload|
        print_failed_upload(upload)
      end
    end
  end
end
