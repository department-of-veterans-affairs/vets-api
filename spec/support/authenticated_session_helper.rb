# frozen_string_literal: true
#
module AuthenticatedSessionHelper
  def use_authenticated_current_user(options = {})
    current_user = options[:current_user] || build(:user)

     expect_any_instance_of(ApplicationController)
       .to receive(:validate_session).at_least(:once).and_return(:true)
     expect_any_instance_of(ApplicationController)
       .to receive(:current_user).at_least(:once).and_return(current_user)
  end

  def sign_in(user = FactoryBot.build(:user, :loa3), token = nil, raw = false)
    user = user.persisted? ? user : User.create(user)
    token ||= 'abracadabra'
    session_object = Session.create(uuid: user.uuid, token: token)
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
