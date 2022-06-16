# frozen_string_literal: true

module Instrumentation
  extend ActiveSupport::Concern
  include SignIn::Authentication

  private

  def append_info_to_payload(payload)
    if @access_token.present?
      payload[:session] = @access_token.session_handle
    elsif session && session[:token]
      payload[:session] = Session.obscure_token(session[:token])
    end
    payload[:user_uuid] = current_user.uuid if current_user.present?
  end
end
