# frozen_string_literal: true

FactoryBot.define do
  factory :preferred_facility do
    facility_code { '983' }
    user { create(:user, :loa3) }

    after(:build) do |preferred_facility|
      allow(preferred_facility.user).to receive(:va_treatment_facility_ids).and_return(
        %w[983 688]
      )
    end
  end
end
