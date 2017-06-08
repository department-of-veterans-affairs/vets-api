# frozen_string_literal: true
module FeatureFlipper
  def self.send_email?
    Settings.reports.token.present? || Rails.env.test?
  end

  def self.staging_email?
    Settings.reports.server.include?('stage')
  end

  def self.evss_upload_workflow?
    Rails.env.development? || Settings.evss.workflow_uploader_enabled
  end
end
