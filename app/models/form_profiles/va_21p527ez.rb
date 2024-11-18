# frozen_string_literal: true

require 'pension_21p527ez/pension_military_information'

# extends app/models/form_profile.rb, which handles form prefill
class FormProfiles::VA21p527ez < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant/information'
    }
  end

  # overrides FormProfile#initialize_military_information
  # to use Pension21p527ez::PensionFormMilitaryInformation instead of
  # FormProfile::FormMilitaryInformation in order to add additional military information fields.
  # @see lib/pension_21p527ez/pension_military_information.rb PensionFormMilitaryInformation
  # @see lib/va_profile/prefill/military_information.rb FormMilitaryInformation
  def initialize_military_information
    return {} unless user.authorize :va_profile, :access?

    military_information_data = {}
    military_information_data.merge!(initialize_va_profile_prefill_military_information)
    military_information_data[:vic_verified] = user.can_access_id_card?
    Pension21p527ez::PensionFormMilitaryInformation.new(military_information_data)
  end

  private

  # overrides FormProfile#initialize_va_profile_prefill_military_information
  # Pension21p527ez::PensionMilitaryInformation instead of
  # FormProfile::MilitaryInformation in order to add additional military information fields.
  # @see lib/pension_21p527ez/pension_military_information.rb PensionMilitaryInformation
  # @see lib/va_profile/prefill/military_information.rb MilitaryInformation
  def initialize_va_profile_prefill_military_information
    military_information_data = {}
    military_information = Pension21p527ez::PensionMilitaryInformation.new(user)

    Pension21p527ez::PensionMilitaryInformation::PREFILL_METHODS.each do |attr|
      military_information_data[attr] = military_information.public_send(attr)
    end

    military_information_data
  rescue => e
    log_exception_to_sentry(e, {}, prefill: :va_profile_prefill_military_information)

    {}
  end
end
