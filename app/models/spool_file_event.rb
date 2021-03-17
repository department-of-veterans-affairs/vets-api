class SpoolFileEvent < ApplicationRecord
  validates(:rpo, inclusion: EducationForm::EducationFacility::FACILITY_IDS)
  validates_uniqueness_of :filename, scope: [:rpo, :filename]

  def self.failed(rpo)
    where(rpo: rpo, successful_at: nil)
  end

  # Look for an existing row with same filename and RPO
  # and increase retry attempt if wasn't successful from previous attempt
  # Otherwise create a new event
  def self.create(rpo, filename)
    event = where(rpo: rpo, filename: filename).first
    event.update(retry_attempt: event.retry_attempt + 1) if successful_at.nil?
    return event if event.present?

    new(rpo: rpo, filename: filename)
  end
end