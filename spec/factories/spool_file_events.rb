# frozen_string_literal: true

FactoryBot.define do
  factory :spool_file_event do
    rpo { EducationForm::EducationFacility::FACILITY_IDS[:western] }
    filename {
      "#{EducationForm::EducationFacility::FACILITY_IDS[:western]}_#{Time.zone.now.strftime('%m%d%Y_%H%M%S')}_vetsgov.spl"
    }

    trait :successful do
      successful_at { Time.zone.now }
    end
  end
end
