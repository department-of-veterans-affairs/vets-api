# frozen_string_literal: true

Pact.provider_states_for 'CoronavirusVaccination' do

  # provider_state 'authenticated user application data' do
  #   set_up do
  #   end

  #   tear_down do
  #   end

	# # no_op - define no_op if a provider state is not necessary
  # end

  provider_state 'unauthenticated user application data' do
    no_op
    # set_up do
    # end

    # tear_down do
    # end

	# no_op - define no_op if a provider state is not necessary
  end
end
