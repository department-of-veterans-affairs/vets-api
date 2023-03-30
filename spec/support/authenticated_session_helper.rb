# frozen_string_literal: true

module AuthenticatedSessionHelper
  def sign_in(user = FactoryBot.build(:user, :loa3), token = nil, raw = false)
    user = user.persisted? ? user : User.create(user)
    token ||= 'abracadabra'
    session_object = Session.create(uuid: user.uuid, token:)
    session_options = { key: 'api_session', secure: false, http_only: true }
    if raw
      Rails::SessionCookie::App.new(session_object.to_hash, session_options).session_cookie
    elsif cookies.is_a?(ActionDispatch::Cookies::CookieJar)
      request.session = session_object.to_hash
    else
      raw_session_cookie = Rails::SessionCookie::App.new(session_object.to_hash, session_options).session_cookie
      cookies.merge(raw_session_cookie)
      raw_session_cookie
    end
  end

  def sign_in_as(user, token = nil)
    sign_in(user, token)
  end
end
