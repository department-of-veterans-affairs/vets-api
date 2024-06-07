# frozen_string_literal: true

FactoryBot.define do
  factory :eligible_data_class do
    name { BB::GenerateReportRequestForm::ELIGIBLE_DATA_CLASSES.sample }
  end
end
