# frozen_string_literal: true

module SignIn
  module Instrumentation
    extend ActiveSupport::Concern

    private

    def append_info_to_payload(payload)
      super
      payload[:session] = @access_token.session_handle if @access_token.present?
      payload[:user_uuid] = current_user.uuid if current_user.present?
    end
  end
end
