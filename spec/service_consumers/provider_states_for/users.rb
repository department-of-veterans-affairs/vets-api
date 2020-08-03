# frozen_string_literal: true

Pact.provider_states_for 'User' do
  provider_state 'user is authenticated' do
    no_op
  end
end
