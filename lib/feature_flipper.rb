# frozen_string_literal: true
module FeatureFlipper
  def self.send_email?
    Settings.reports.token.present? || Rails.env.test?
  end

  def self.staging_email?
    Settings.reports.server.include?('stage')
  end

  def self.enable_prefill?(user)
    return false unless user&.ssn
    # Many of our test users have SSNs that begin with the unused 796
    # prefix, so gating on that should limit it to 'our' users.
    user.ssn.to_s.starts_with?('796')
  end
end
