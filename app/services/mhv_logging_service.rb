# frozen_string_literal: true

require 'mhv_logging/client'
class MHVLoggingService
  def self.login(current_user)
    if current_user.loa3? && current_user.mhv_correlation_id && !current_user.mhv_last_signed_in
      MHV::AuditLoginJob.perform_async(current_user.uuid)
      true
    else
      false
    end
  end

  def self.logout(current_user)
    if current_user.mhv_last_signed_in
      MHV::AuditLogoutJob.perform_async(current_user.uuid, current_user.mhv_correlation_id)
      true
    else
      false
    end
  end
end
