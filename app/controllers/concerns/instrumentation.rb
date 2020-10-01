# frozen_string_literal: true

module Instrumentation
  extend ActiveSupport::Concern

  private

  def append_info_to_payload(payload)
    super
    payload[:session] = Session.obscure_token(session[:token]) if session && session[:token]
    payload[:user_uuid] = current_user.uuid if current_user.present?
  end
end
