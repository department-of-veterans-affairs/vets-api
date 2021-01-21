# frozen_string_literal: true

Pact.provider_states_for 'My Messages' do
  provider_state 'logged in user with messages' do
    set_up do
      build_user_and_stub_session
    end
  end

  provider_state 'not logged in' do
    no_op
  end
end
