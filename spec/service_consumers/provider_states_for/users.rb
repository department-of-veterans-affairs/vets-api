# frozen_string_literal: true

Pact.provider_states_for 'Users' do
  provider_state 'show user profile' do
    set_up do
      # user = double('user')
      # user = FactoryBot.build(:user, :loa1)
      # allow(request.env['warden']).to receive(:authenticate!).and_return(user)
      # allow(controller).to receive(:current_user).and_return(user)
      # cookie = sign_in(user, nil, true)
      # binding.pry
      # form = FactoryBot.create(:in_progress_form, user_uuid: user.uuid, form_id: 'edu-1990')
      # binding.pry
      # return if Rails.env.production?

      # User.first || FactoryBot.create(:user)
    end
  end
end
