# frozen_string_literal: true

FactoryBot.define do
  factory :full_name, class: 'Preneeds::FullName' do
    last { generate(:last_name) }
    first { generate(:first_name) }
    middle { generate(:middle_name) }
    maiden { generate(:maiden_name) }

    suffix { 'Jr.' }
  end
end
