# frozen_string_literal: true

Pact.provider_states_for 'Contact Us' do
  provider_state 'minimum required data' do
    no_op # nothing to setup or tear down
  end
end
