# frozen_string_literal: true

Pact.provider_states_for 'VA.gov' do
  provider_state 'user is logged in' do
    set_up do
      sign_in
    end
  end
end
