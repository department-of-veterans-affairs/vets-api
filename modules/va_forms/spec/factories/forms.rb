# frozen_string_literal: true

FactoryBot.define do
  factory :va_form, class: 'VAForms::Form' do
    form_name { '526ez' }
    row_id { 4909 }
    url { 'https://va.gov/va_form/21-526ez.pdf' }
    title { 'Disability Compensation' }
    first_issued_on { Time.zone.today - 1.day }
    last_revision_on { Time.zone.today }
    pages { 2 }
    valid_pdf { true }
    sequence(:sha256) { |n| "abcd#{n}" }
    last_sha256_change { sha256 }
    form_usage { 'Usage description' }
    form_tool_intro { 'Introduction to form tool' }
    form_tool_url { 'https://va.gov/tool' }
    form_details_url { 'https://va.gov/form_details' }
    form_type { 'PDF' }
    language { 'English' }
    related_forms { %w[related_form_1 related_form_2] }
    benefit_categories { %w[benefit_category_1 benefit_category_2] }
    va_form_administration { ['VA Administration'] }
    change_history { { 'versions' => %w[v1 v2] } }

    trait :has_been_deleted do
      deleted_at { '2020-07-16T00:00:00.000Z' }
    end

    factory :deleted_va_form, parent: :va_form do
      has_been_deleted
      form_name { '528' }
      row_id { 1315 }
    end
  end
end
