# frozen_string_literal: true

FactoryBot.define do
  factory :debts_api_form5655_submission, class: 'DebtsApi::V0::Form5655Submission' do
    transient do
      user { create(:user, :loa3) }
    end
    user_uuid { user.uuid }
    form_json do
      JSON.parse(
        File.read(
          Rails.root.join(*'/modules/debts_api/spec/fixtures/form5655_submission.json'.split('/')).to_s
        )
      ).to_json
    end
  end
end
