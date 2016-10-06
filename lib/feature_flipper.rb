# frozen_string_literal: true
module FeatureFlipper
  def self.show_education_benefit_form?
    # Visible in all situations except in production where EDU_FORM_SHOW is not true
    !(Rails.env.production? && ENV['EDU_FORM_SHOW'] != 'true')
  end
end
