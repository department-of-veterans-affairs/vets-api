# frozen_string_literal: true
require 'mhv_logging/client'
module MHVLogging
  class Service
    def self.login(current_user)
      # If login has already been submitted, do nothing
      return if current_user.mhv_last_signed_in
      # Otherwise send the login audit trail
      MHVLogging::Client.new(session: { user_id: mhv_correlation_id })
        .authenticate
        .auditlogin
      # Update the user object with the time of login
      current_user.mhv_last_signed_in = Time.current
      current_user.save
    end

    def self.logout(current_user)
      # If login has never been sent, no need to send logout
      return unless current_user.mhv_last_signed_in
      # Otherwise send the logout audit trail
      MHVLogging::Client.new(session: { user_id: mhv_correlation_id })
        .authenticate
        .auditlogout
      # Update the user object with nil to indicate not logged in
      current_user.mhv_last_signed_in = nil
      current_user.save
    end
  end
end
