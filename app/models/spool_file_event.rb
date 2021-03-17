class SpoolFileEvent < ApplicationRecord
  validates(:rpo, inclusion: EducationForm::EducationFacility::FACILITY_IDS)

  def self.failed(rpo)
    where(rpo: rpo, successful_at: nil)
  end

  # Look for an existing row with same filename and RPO, filename contains a date so this combo
  def self.create(rpo, filename)
    event = where(rpo: rpo, filename: filename).first
    event.update(retry_attempt: event.retry_attempt + 1)
    return event if event.present?

    new(rpo: rpo, filename: filename)
  end
end