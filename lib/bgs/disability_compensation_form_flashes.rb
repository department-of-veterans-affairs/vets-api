# frozen_string_literal: true

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

    def als?
      feature_enabled = Flipper.enabled?(:disability_526_ee_process_als_flash, @user)
      add_als = ClaimFastTracking::FlashPicker.als?(@claimed_disabilities)
      Rails.logger.info('FlashPicker for ALS', { feature_enabled: }) if add_als
      feature_enabled && add_als
    rescue => e
      Rails.logger.error("Failed to determine need for ALS flash: #{e.message}.", backtrace: e.backtrace)
      false
    end
  end
end
