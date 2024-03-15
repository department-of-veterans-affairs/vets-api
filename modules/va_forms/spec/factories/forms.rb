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
    last_sha256_change { Date.new(2024, 3, 15) }
    change_history do
      { 'versions' =>
         [{ 'sha256' => 'a8ba72e148e15e4e03476bb7fbbdbc4facd43ceb52d10eb2f605a8aa8b4bad6a',
            'revision_on' => '2024-01-08' },
          { 'sha256' => '68b6d817881be1a1c8f323a9073a343b81d1c5a6e03067f27fe595db77645c22',
            'revision_on' => '2024-03-15' }] }
    end
    sequence(:sha256) { |n| "abcd#{n}" }

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
