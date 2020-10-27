# frozen_string_literal: true

Pact.provider_states_for 'Contact Us' do

  # define multiple provider states as needed for each interaction in the pact
  provider_state 'minimum required data' do
    set_up do
    end

    tear_down do
    end

	# no_op - define no_op if a provider state is not necessary
  end
end
