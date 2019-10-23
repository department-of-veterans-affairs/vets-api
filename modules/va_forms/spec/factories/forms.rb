# frozen_string_literal: true

FactoryBot.define do
  factory :va_form, class: 'VaForms::Form' do
    form_name { '526ez' }
    url { 'https://va.gov/va_form/21-526ez.pdf' }
    title { 'Disability Compensation' }
    first_issued_on { Time.zone.today }
    last_revision_on { Time.zone.today }
    pages { 2 }
    sha256 { 'somelongsha' }
  end
end
