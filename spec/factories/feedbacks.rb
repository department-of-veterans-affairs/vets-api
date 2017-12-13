# frozen_string_literal: true
FactoryBot.define do
  factory :feedback, class: 'Feedback' do
    target_page '/example/page'
    description 'I liked this page very much.  I used it to help me attain benefits and it was simple and intuitive'

    trait :email_provided do
      owner_email 'joe.vet@aol.com'
    end

    trait :malicious_email do
      owner_email '@session.token'
    end

    trait :sensitive_data_in_body do
      description 'My email is joe@vets.com.  Page was hard, here is my ssn 111-22-3333.'
    end
  end
end
