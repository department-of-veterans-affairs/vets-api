# frozen_string_literal: true

# GCIO Form Intake Integration Configuration

module FormIntake
  # Forms eligible for GCIO integration
  # Each form must also have a feature flag and mapper
  ELIGIBLE_FORMS = [
    # Forms will be added here as implemented
    # Example:
    # '21P-601',
    # '21-0966',
  ].freeze

  # Map each form to its feature flag for independent control
  FORM_FEATURE_FLAGS = {
    # Forms will be added here as implemented
    # Example:
    # '21P-601' => :form_intake_integration_601,
    # '21-0966' => :form_intake_integration_0966,
  }.freeze

  # Check if GCIO is enabled for a specific form
  # @param form_id [String] Form type ID
  # @param user_account [UserAccount, nil] Optional user account for actor-based flags.
  #                                         For unauthenticated forms, pass nil - Flipper will check global enable only.
  # @return [Boolean]
  def self.enabled_for_form?(form_id, user_account = nil)
    # Form not in eligible list? Not enabled
    return false unless ELIGIBLE_FORMS.include?(form_id)

    # Form has no feature flag? Not enabled
    flag = FORM_FEATURE_FLAGS[form_id]
    return false unless flag

    # Check if feature flag is enabled
    Flipper.enabled?(flag, user_account)
  rescue => e
    # Fail closed - if Flipper errors, don't enable GCIO
    Rails.logger.error('FormIntake feature flag check failed',
                       form_id:,
                       flag:,
                       error: e.message,
                       error_class: e.class.name)
    StatsD.increment('form_intake.flipper_check_failed', tags: ["form_id:#{form_id}"])
    false
  end

  # List forms currently enabled (with flags turned on)
  # @return [Array<String>] Form type IDs
  def self.enabled_forms
    ELIGIBLE_FORMS.select do |form_id|
      flag = FORM_FEATURE_FLAGS[form_id]
      flag && Flipper.enabled?(flag)
    end
  end
end
