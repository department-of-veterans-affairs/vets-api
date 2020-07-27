# frozen_string_literal: true

Pact.provider_states_for 'Users' do
  provider_state 'show user profile' do
    set_up do
      # return if Rails.env.production?

      # user = FactoryBot.build(:user, :loa3)
      # sign_in_as(user)
      # FactoryBot.create(:in_progress_form, user_uuid: user.uuid, form_id: 'edu-1990')
    end
  end
end
