# frozen_string_literal: true

module FeatureFlipper
  def self.send_email?
    Settings.govdelivery.token.present? || Rails.env.test?
  end

  def self.staging_email?
    Settings.govdelivery.staging_service
  end

  def self.send_edu_report_email?
    send_email? && Settings.reports.send_email
  end
end
