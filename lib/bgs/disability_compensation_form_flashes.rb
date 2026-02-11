# frozen_string_literal: true

require 'bgs/monitor'

module BGS
  class DisabilityCompensationFormFlashes
    def initialize(user, form_content, claimed_disabilities)
      @user = user
      @form_content = form_content['form526']
      @claimed_disabilities = claimed_disabilities
      @flashes = []
    end

    # Merges the user data and performs the translation
    #
    # @return [Hash] The translated form(s) ready for submission
    #
    # we've started with the flashes that are the most straightforward to determine, but should
    # consider these flashes soon
    #
    # "Agent Orange - Vietnam",
    # "Amyotrophic Lateral Sclerosis",
    # "Blind",
    # "Blue Water Navy",
    # "Formerly Homeless",
    # "GW Undiagnosed Illness",
    # "Hardship",
    # "Medal of Honor",
    # "Purple Heart",
    # "Seriously Injured/Very Seriously Injured",
    # "Specially Adapted Housing Claimed",

    def translate
      @flashes << 'Homeless' if homeless?
      @flashes << 'Terminally Ill' if terminally_ill?
      @flashes << 'Priority Processing - Veteran over age 85' if over_85?
      @flashes << 'POW' if pow?
      @flashes << 'Amyotrophic Lateral Sclerosis' if als?
      @flashes
    end

    def homeless?
      @form_content['homelessOrAtRisk'] == 'homeless'
    end

    def terminally_ill?
      @form_content['isTerminallyIll'] == true
    end

    def over_85?
      85.years.ago > @user.birth_date.to_date
    end

    def pow?
      @form_content['confinements'].present?
    end

    # Determines if the claim should be flagged with "Amyotrophic Lateral Sclerosis" flash.
    # Flashes are used by VA to properly route and prioritize claims.
    #
    # Uses ClaimFastTracking::FlashPicker to detect ALS-related conditions in the claimed
    # disabilities through exact and fuzzy string matching. Requires the
    # disability_526_ee_process_als_flash feature flag to be enabled for the user.
    #
    # @return [Boolean] true if both the feature is enabled and ALS is detected in claimed disabilities
    def als?
      feature_enabled = Flipper.enabled?(:disability_526_ee_process_als_flash, @user)
      add_als = ClaimFastTracking::FlashPicker.als?(@claimed_disabilities)
      monitor.info('FlashPicker for ALS', 'als_check', feature_enabled:) if add_als
      feature_enabled && add_als
    rescue => e
      monitor.error("Failed to determine need for ALS flash: #{e.message}.", 'als_error', backtrace: e.backtrace)
      false
    end

    # Returns a BGS monitor instance for logging.
    #
    # @return [BGS::Monitor] configured monitor with allowlist for safe logging
    # @note Allowlist prevents PII leakage while capturing feature flags and debug info
    def monitor
      @monitor ||= BGS::Monitor.new(allowlist: %w[feature_enabled backtrace])
    end
  end
end
