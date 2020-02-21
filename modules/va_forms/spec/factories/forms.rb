# frozen_string_literal: true

FactoryBot.define do
  factory :va_form_526ez, class: 'VaForms::Form' do
    form_name { '526ez' }
    url { 'https://va.gov/va_form/21-526ez.pdf' }
    title { 'Disability Compensation' }
    first_issued_on { Time.zone.today - 1.day }
    last_revision_on { Time.zone.today }
    pages { 2 }
    sha256 { 'somelongsha' }
  end

  factory :va_form_10ez, class: 'VaForms::Form' do
    form_name { '10-10EZ (pdf)' }
    url { 'https://www.va.gov/vaforms/medical/pdf/10-10EZ-fillable.pdf' }
    title { 'Instructions For Completing Enrollment Application For Health Benefits' }
    first_issued_on { Time.zone.today - 1.day }
    last_revision_on { Time.zone.today }
    pages { 5 }
    sha256 { 'somelongsha' }
  end
end
