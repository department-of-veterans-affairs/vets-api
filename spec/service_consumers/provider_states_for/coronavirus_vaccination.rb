# frozen_string_literal: true

Pact.provider_states_for 'Coronavirus Vaccination' do
  provider_state 'retrieves previously saved submission data for user' do
    set_up do
      user = build_user_and_stub_session
      submission = CovidVaccine::V0::RegistrationSubmission.for_user(user).last
      submission || FactoryBot.create(:covid_vax_registration)
    end

    tear_down do
    end
  end

  provider_state 'submission data for user does not exist' do
    set_up do
      user = build_user_and_stub_session
      CovidVaccine::V0::RegistrationSubmission.for_user(user).last
    end

    tear_down do
    end
  end

  provider_state 'authenticated user submits registration data' do
    set_up do
      build_user_and_stub_session
    end

    tear_down do
    end
  end

  provider_state 'unauthenticated user submits registration data' do
    no_op
  end
end
