class SpoolFileEvent < ApplicationRecord
  validates(:rpo, inclusion: EducationForm::EducationFacility::FACILITY_IDS)

  def self.failed(rpo)
    where(rpo: rpo, successful_at: nil)
  end
end