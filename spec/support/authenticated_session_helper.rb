# frozen_string_literal: true

module AuthenticatedSessionHelper
  def use_authenticated_current_user(options = {})
    current_user = options[:current_user] || build(:user)

    expect_any_instance_of(ApplicationController)
      .to receive(:validate_session).at_least(:once).and_return(:true)
    expect_any_instance_of(ApplicationController)
      .to receive(:current_user).at_least(:once).and_return(current_user)
  end

  def sign_in(user = nil, token = nil)
    user ||= User.create(build(:user, :loa3))
    token ||= 'abracadabra'
    session_object = Session.create(uuid: user.uuid, token: token)
    session_options = { key: 'api_session', secure: false, http_only: true }
    raw_session_cookie = Rails::SessionCookie::App.new(session_object.to_hash, session_options).session_cookie
    cookies.merge(raw_session_cookie)
  end

  def sign_in_as(user)
    sign_in(user)
  end
end
