# frozen_string_literal: true

class SpoolFileEvent < ApplicationRecord
  validates(:rpo, inclusion: EducationForm::EducationFacility::FACILITY_IDS.values)
  validates :filename, uniqueness: { scope: %i[rpo filename] }

  # Look for an existing row with same filename and RPO
  # and increase retry attempt if wasn't successful from previous attempt
  # Otherwise create a new event
  def self.build_event(rpo, filename)
    filename_rpo_date = filename.match(/(.+)_(.+)_/)[1]
    find_by_sql = sanitize_sql_for_conditions(['rpo = :rpo AND filename like :filename',
                                               { rpo:,
                                                 filename: "#{filename_rpo_date}%" }])
    event = find_by(find_by_sql)
    if event.present?
      event.update(retry_attempt: event.retry_attempt + 1) if event.successful_at.nil?
      return event
    end

    create(rpo:, filename:)
  end
end
