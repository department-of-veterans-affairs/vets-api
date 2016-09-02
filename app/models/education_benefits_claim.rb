# frozen_string_literal: true
class EducationBenefitsClaim < ActiveRecord::Base
  # TODO: encrypt sensitive information in education_benefits_claims #42
  validates(:form, presence: true)
  serialize :form, JSON

  # initially only completed claims are allowed, later we can allow claims that dont have a submitted_at yet
  before_validation(:set_submitted_at, on: :create)

  def set_submitted_at
    self.submitted_at = Time.zone.now
  end

  def open_struct_form
    @application ||= JSON.parse(self['form'].to_json, object_class: OpenStruct)
    @application.form = application_type
    @application
  end

  def self.unprocessed_for(date)
    where(processed_at: nil).where("submitted_at > ? and submitted_at < ?", date.beginning_of_day, date.end_of_day)
  end

  # TODO: Add logic for determining field type(s) that need to be places in the application header
  def application_type
    if @application.chapter1606
      return 'CH1606'
    end
  end
end
