# frozen_string_literal: true

Pact.provider_states_for 'Coronavirus Vaccination' do
  provider_state 'retreives saved registration for authenticated user' do
    user = build_user_and_stub_session
    submission = CovidVaccine::V0::RegistrationSubmission.for_user(user).last
    submission || FactoryBot.create(
      :covid_vaccine_registration_submission,
      firstName: user.first_name,
      lastName: user.last_name,
      birthDate: user.birth_date,
      ssn: user.ssn,
      email: user.email,
      zipCode: user.zip,
    )

    # user = build_user_and_stub_session
    # form = InProgressForm.form_for_user(form_id, user)
    # form || FactoryBot.create(:hca_in_progress_form, form_id: form_id, user_uuid: user.uuid)
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
