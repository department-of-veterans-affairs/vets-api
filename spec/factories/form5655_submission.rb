# frozen_string_literal: true

FactoryBot.define do
  factory :form5655_submission do
    transient do
      user { create(:user, :loa3) }
    end
    user_uuid { user.uuid }
    form_json do
      JSON.parse(File.read(::Rails.root.join(*'/spec/fixtures/dmc/form5655_submission.json'.split('/')).to_s)).to_json
    end
  end
end
