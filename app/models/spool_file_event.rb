class SpoolFileEvent < ApplicationRecord
  validates(:rpo, inclusion: EducationForm::EducationFacility::FACILITY_IDS.values)
  validates_uniqueness_of :filename, scope: [:rpo, :filename]

  # Look for an existing row with same filename and RPO
  # and increase retry attempt if wasn't successful from previous attempt
  # Otherwise create a new event
  def self.build_event(rpo, filename)
    event = SpoolFileEvent.where(rpo: rpo, filename: filename).first
    if event.present?
      event.update(retry_attempt: event.retry_attempt + 1) if event.successful_at.nil?
      return event
    end

    SpoolFileEvent.create(rpo: rpo, filename: filename)
  end
end