# frozen_string_literal: true

def build_user_and_stub_session
  user = FactoryBot.build(:user, :loa3, va_patient: true, middle_name: 'J')
  session_object = sign_in(user, nil, nil, true)
  allow_any_instance_of(ActionDispatch::Request).to receive(:session).and_return(session_object.to_hash)
  user
end
