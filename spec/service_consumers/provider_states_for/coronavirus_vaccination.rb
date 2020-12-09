# frozen_string_literal: true

Pact.provider_states_for 'Coronavirus Vaccination' do

  provider_state 'authenticated user application data' do
    set_up do
      build_user_and_stub_session
    end

    tear_down do
    end
  end

  provider_state 'unauthenticated user application data' do
    no_op
  end

  # provider_state 'template' do
  #   set_up do
  #   end

  #   tear_down do
  #   end

	# # no_op - define no_op if a provider state is not necessary
  # end
end
