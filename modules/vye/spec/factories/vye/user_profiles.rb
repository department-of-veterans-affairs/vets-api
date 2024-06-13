# frozen_string_literal: true

FactoryBot.define do
  digit = proc { rand(0..9).to_s }

  factory :vye_user_profile, class: 'Vye::UserProfile' do
    ssn { (1..9).map(&digit).join }
    file_number { (1..9).map(&digit).join }
    icn { SecureRandom.uuid }

    after(:create) do |user_profile|
      create_list(:vye_pending_document, 3, user_profile:)
    end
  end
end
