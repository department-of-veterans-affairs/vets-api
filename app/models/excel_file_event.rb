# frozen_string_literal: true

class ExcelFileEvent < ApplicationRecord
  validates :filename, uniqueness: true

  # Look for an existing row with same filename
  # and increase retry attempt if wasn't successful from previous attempt
  # Otherwise create a new event
  def self.build_event(filename)
    filename_date = filename.match(/(.+)_/)[1]
    event = find_by('filename like ?', "#{filename_date}%")

    if event.present?
      event.update(retry_attempt: event.retry_attempt + 1) if event.successful_at.nil?
      return event
    end

    create(filename:)
  end
end
