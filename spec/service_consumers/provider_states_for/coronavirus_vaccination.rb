# frozen_string_literal: true

Pact.provider_states_for 'Coronavirus Vaccination' do
  provider_state 'registration data exists' do
    set_up do
      user = build_user_and_stub_session
      submission = CovidVaccine::V0::RegistrationSubmission.for_user(user).last
      submission || FactoryBot.create(:covid_vax_registration, account_id: user.account_uuid)
    end

    tear_down do
    end
  end

  provider_state 'registration data does not exist' do
    set_up do
      user = build_user_and_stub_session
      FactoryBot.create(:covid_vax_registration, :unsubmitted, account_id: user.account_uuid)
      # or should I not create an unsubmitted registration and
      # follow this example - line 245, modules/covid_vaccine/spec/request/covid_vaccine/v0/registration_request_spec.rb
    end

    tear_down do
    end
  end

  provider_state 'authenticated user submits registration data' do
    set_up do
      build_user_and_stub_session
      # what to do next?
    end

    tear_down do
    end
  end

  provider_state 'unauthenticated user submits registration data' do
    no_op
  end
end
