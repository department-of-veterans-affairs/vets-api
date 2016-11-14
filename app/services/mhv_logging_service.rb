# frozen_string_literal: true
require 'mhv_logging/client'
class MHVLoggingService
  def self.login(current_user)
    # If login has already been submitted, do nothing
    return false if current_user.mhv_correlation_id.nil? || current_user.mhv_last_signed_in
    # Otherwise send the login audit trail
    MHV::AuditLoginJob.perform_async(current_user.uuid)
    true
  end

  def self.logout(current_user)
    # If login has never been sent, no need to send logout
    return false unless current_user.mhv_correlation_id.nil? || current_user.mhv_last_signed_in
    # Otherwise send the logout audit trail
    MHV::AuditLogoutJob.perform_async(current_user.uuid, current_user.mhv_correlation_id)
    true
  end
end
