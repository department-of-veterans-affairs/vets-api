class EducationBenefitsClaim < ActiveRecord::Base
  validates(:form, presence: true)

  # initially only completed claims are allowed, later we can allow claims that dont have a submitted_at yet
  before_validation(:set_submitted_at, on: :create)

  def set_submitted_at
    self.submitted_at = Time.zone.now
  end
end
