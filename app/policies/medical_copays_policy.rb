# frozen_string_literal: true

MedicalCopaysPolicy = Struct.new(:user, :medical_copays) do
  ##
  # Determines if the authenticated user has
  # access to the Medical Copays feature
  #
  # @return [Boolean]
  #
  def access?
    accessible = user.edipi.present? && user.icn.present?
    StatsD.increment("api.mcp.policy.#{accessible ? 'success' : 'failure'}")

    accessible
  end

  def access_notifications?
    accessible = Flipper.enabled?('medical_copay_notifications')
    if accessible
      StatsD.increment('api.mcp.notification_policy.success')
    else
      StatsD.increment('api.mcp.notification_policy.failure')
    end

    accessible
  end
end
