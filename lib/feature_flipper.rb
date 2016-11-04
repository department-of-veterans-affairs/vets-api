# frozen_string_literal: true
module FeatureFlipper
  def self.show_education_benefit_form?
    # Visible in all situations except in production where EDU_FORM_SHOW is not true
    !(Rails.env.production? && ENV['EDU_FORM_SHOW']&.downcase != 'true')
  end

  def self.send_email?
    ENV['GOV_DELIVERY_TOKEN'].present? || Rails.env.test?
  end

  def self.staging_email?
    ENV['GOV_DELIVERY_SERVER'].include?('stage')
  end
end
