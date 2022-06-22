# frozen_string_literal: true

module SignIn
  module Instrumentation
    extend ActiveSupport::Concern

    private

    def append_info_to_payload(payload)
      super
      payload[:session] = session if @access_token.present?
      payload[:user_uuid] = current_user.uuid if current_user.present?
    end

    def session
      @access_token.session_handle
    end
  end
end
