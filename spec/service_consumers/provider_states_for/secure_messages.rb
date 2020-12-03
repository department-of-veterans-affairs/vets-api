# frozen_string_literal: true

Pact.provider_states_for 'My Messages' do
  provider_state 'Logged In User With Messages' do
    set_up do
      build_user_and_stub_session
    end
  end

  provider_state 'not logged in' do
    no_op
  end
end
