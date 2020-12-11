# frozen_string_literal: true

Pact.provider_states_for 'Coronavirus Vaccination' do
  provider_state 'retreives saved registration for authenticated user' do
    user = build_user_and_stub_session
    submission = CovidVaccine::V0::RegistrationSubmission.for_user(user).last
    submission || FactoryBot.create(:covid_vaccine_registration_submission)
  end

  provider_state 'authenticated user sumbits registration data' do
    set_up do
      build_user_and_stub_session
    end

    tear_down do
    end
  end

  provider_state 'unauthenticated user sumbits registration data' do
    no_op
  end

  provider_state 'authenticated user updates registration data' do
    set_up do
      build_user_and_stub_session
    end

    tear_down do
    end
  end
end
