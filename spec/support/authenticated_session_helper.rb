# frozen_string_literal: true

module AuthenticatedSessionHelper
  def authenticated_user(options = {})
    current_user = User.create(options[:current_user] || build(:user))
    session = Session.create(uuid: current_user.uuid, token: 'abracadabra')

    allow_any_instance_of(ApplicationController)
      .to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController)
      .to receive(:current_user).and_return(current_user)
    allow_any_instance_of(ApplicationController)
      .to receive(:session_object).and_return(session)
  end

  def unauthenticated_user
    allow_any_instance_of(ApplicationController)
      .to receive(:validate_session).and_return(false)
    allow_any_instance_of(ApplicationController)
      .to receive(:current_user).and_return(nil)
    allow_any_instance_of(ApplicationController)
      .to receive(:session).and_return(nil)
  end

  def sign_in(user = FactoryBot.build(:user, :loa3), token = nil)
    user = user.persisted? ? user : User.create(user)
    token ||= 'abracadabra'
    session_object = Session.create(uuid: user.uuid, token: token)
    if cookies.is_a?(ActionDispatch::Cookies::CookieJar)
      request.session = session_object.to_hash
    else
      session_options = { key: 'api_session', secure: false, http_only: true }
      raw_session_cookie = Rails::SessionCookie::App.new(session_object.to_hash, session_options).session_cookie
      cookies.merge(raw_session_cookie)
    end
  end

  def sign_in_as(user, token = nil)
    sign_in(user, token)
  end
end
