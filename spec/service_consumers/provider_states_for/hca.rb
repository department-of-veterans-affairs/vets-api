# frozen_string_literal: true

Pact.provider_states_for 'HCA' do
  provider_state 'a saved form exists' do
    set_up do
      user = build_user_and_stub_session
      form_id = '1010ez'
      form = InProgressForm.form_for_user(form_id, user)
      form || FactoryBot.create(:hca_in_progress_form, form_id: form_id, user_uuid: user.uuid)
    end

    tear_down do
    end
  end

  provider_state 'user is authenticated' do
    set_up do
      build_user_and_stub_session
    end

    tear_down do
    end
  end

  provider_state 'enrollment service is up' do
    set_up do
      VCR.insert_cassette('hca/enrollment_service')
    end

    tear_down do
      VCR.eject_cassette
    end
  end
end
