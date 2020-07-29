# frozen_string_literal: true

require 'support/authenticated_session_helper'

class AddAuthenticationHeaders
  include AuthenticatedSessionHelper

  def initialize app
    @app = app
  end

  def call env
    user = FactoryBot.build(:user, :loa3)
    user = user.persisted? ? user : User.create(user)
    token ||= 'abracadabra'
    session_object = Session.create(uuid: user.uuid, token: token)
    session_options = { key: 'api_session', secure: false, http_only: true }
    raw_cookie =  Rails::SessionCookie::App.new(session_object.to_hash, session_options).session_cookie

    env['rack.session'] = session_object.to_hash
    env['rack.session.options'] = session_options
    
    status, headers, body = @app.call(env)

    [status, headers, body]
  end
  
end
