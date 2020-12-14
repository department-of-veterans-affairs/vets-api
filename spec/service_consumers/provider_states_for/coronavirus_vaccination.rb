# frozen_string_literal: true

Pact.provider_states_for 'Coronavirus Vaccination' do
  provider_state 'retrieves previously saved submission data for user' do
    set_up do
      user = build_user_and_stub_session
      submission = CovidVaccine::V0::RegistrationSubmission.for_user(user).last
      submission || FactoryBot.create(:covid_vaccine_registration_submission)
    end

    tear_down do
    end
  end

  provider_state 'does not retrieve perviously saved submission data for user becase it does not exist' do
    set_up do
      user = build_user_and_stub_session
      CovidVaccine::V0::RegistrationSubmission.for_user(user).last
    end

    tear_down do
    end
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
end
