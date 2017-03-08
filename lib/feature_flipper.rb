# frozen_string_literal: true
module FeatureFlipper
  def self.show_education_benefit_form?
    # Visible in all situations except in production where Settings.edu.show_form is not true
    !(Rails.env.production? && Settings.edu.show_form)
  end

  def self.send_email?
    Settings.reports.token.present? || Rails.env.test?
  end

  def self.staging_email?
    Settings.reports.server.include?('stage')
  end
end
