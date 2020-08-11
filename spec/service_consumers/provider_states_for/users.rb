# frozen_string_literal: true

Pact.provider_states_for 'User' do
  provider_state 'user is authenticated' do
    set_up do
      user = FactoryBot.build(:user, :loa3, va_patient: true, middle_name: 'J')
      session_object = sign_in(user, nil, nil, true)
      allow_any_instance_of(ActionDispatch::Request).to receive(:session).and_return(session_object.to_hash)
    end

    tear_down do
    end
  end
end
