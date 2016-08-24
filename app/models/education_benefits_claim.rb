class EducationBenefitsClaim < ActiveRecord::Base
  after_initialize(:set_submitted_at)

  validates(:json, :submitted_at, presence: true)

  def set_submitted_at
    self.submitted_at ||= Time.zone.now
  end
end
