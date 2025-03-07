# frozen_string_literal: true

FactoryBot.define do
  factory :debts_api_form5655_submission, class: 'DebtsApi::V0::Form5655Submission' do
    transient do
      user { create(:user, :loa3, :with_terms_of_use_agreement, idme_uuid: SecureRandom.uuid) }
    end
    user_uuid { user.uuid }
    user_account { user.user_account }
    form_json do
      JSON.parse(
        File.read(
          Rails.root.join(*'/modules/debts_api/spec/fixtures/form5655_submission.json'.split('/')).to_s
        )
      ).to_json
    end
  end
  factory :debts_api_sw_form5655_submission, class: 'DebtsApi::V0::Form5655Submission' do
    transient do
      user { create(:user, :loa3) }
    end
    user_uuid { user.uuid }
    form_json do
      JSON.parse(
        File.read(Rails.root.join(*'/modules/debts_api/spec/fixtures/sw_form5655_submission.json'.split('/')).to_s)
      ).to_json
    end
  end
  factory :debts_api_non_sw_form5655_submission, class: 'DebtsApi::V0::Form5655Submission' do
    transient do
      user { create(:user, :loa3) }
    end
    user_uuid { user.uuid }
    form_json do
      JSON.parse(
        File.read(Rails.root.join(*'/modules/debts_api/spec/fixtures/non_sw_form5655_submission.json'.split('/')).to_s)
      ).to_json
    end
  end
end
