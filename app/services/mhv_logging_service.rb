# frozen_string_literal: true
require 'mhv_logging/client'
class MHVLoggingService
  def self.login(current_user)
    # If login has already been submitted, do nothing
    return false if current_user.mhv_last_signed_in || current_user.mhv_correlation_id.nil?
    # Otherwise send the login audit trail
    MHVLogging::Client.new(session: { user_id: current_user.mhv_correlation_id })
      .authenticate
      .auditlogin
    # Update the user object with the time of login
    current_user.mhv_last_signed_in = Time.current
    current_user.save
    true
  end

  def self.logout(current_user)
    # If login has never been sent, no need to send logout
    return false unless current_user.mhv_last_signed_in || current_user.mhv_correlation_id.nil?
    # Otherwise send the logout audit trail
    MHVLogging::Client.new(session: { user_id: current_user.mhv_correlation_id })
      .authenticate
      .auditlogout
    # Update the user object with nil to indicate not logged in
    current_user.mhv_last_signed_in = nil
    current_user.save
    true
  end
end
