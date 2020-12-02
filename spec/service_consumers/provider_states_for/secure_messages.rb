# frozen_string_literal: true

Pact.provider_states_for 'My Messages' do
  provider_state 'Logged In User With Messages' do
    set_up do
      build_user_and_stub_session
    end
  end
end
