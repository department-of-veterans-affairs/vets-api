# frozen_string_literal: true

FactoryBot.define do
  factory :form5655_submission do
    transient do
      user { create(:user, :loa3) }
    end
    user_uuid { user.uuid }
    form_json do
      JSON.parse(File.read("#{::Rails.root}/spec/fixtures/dmc/fsr_submission.json")).to_json
    end
  end
end
