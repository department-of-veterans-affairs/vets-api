# frozen_string_literal: true

require 'pensions/military_information'

module Pensions
  # extends app/models/form_profile.rb, which handles form prefill
  class FormProfiles::VA21p527ez < ::FormProfile
    ##
    # Returns metadata related to the form profile
    #
    # @return [Hash]
    def metadata
      {
        version: 0,
        prefill: true,
        returnUrl: '/applicant/information'
      }
    end

    ##
    # Initializes military information for a user if they are authorized
    #
    # Overrides FormProfile#initialize_military_information to use Pensions::FormMilitaryInformation instead of
    # FormProfile::FormMilitaryInformation in order to add additional military information fields.
    # @see modules/pensions/lib/pensions/military_information.rb Pensions::FormMilitaryInformation
    # @see lib/va_profile/prefill/military_information.rb FormMilitaryInformation
    #
    # @return [FormMilitaryInformation, Hash]
    def initialize_military_information
      return {} unless user.authorize :va_profile, :access?

      military_information_data = {}
      military_information_data.merge!(initialize_va_profile_prefill_military_information)
      military_information_data[:vic_verified] = user.can_access_id_card?
      Pensions::FormMilitaryInformation.new(military_information_data)
    end

    private

    ##
    # Initializes military information from VA Profile for prefill purposes
    #
    # Overrides FormProfile#initialize_va_profile_prefill_military_information Pensions::MilitaryInformation instead of
    # FormProfile::MilitaryInformation in order to add additional military information fields.
    # @see lib/pension_21p527ez/pension_military_information.rb PensionMilitaryInformation
    # @see lib/va_profile/prefill/military_information.rb MilitaryInformation
    #
    # @return [Hash]
    def initialize_va_profile_prefill_military_information
      military_information_data = {}
      military_information = Pensions::MilitaryInformation.new(user)

      Pensions::MilitaryInformation::PREFILL_METHODS.each do |attr|
        military_information_data[attr] = military_information.public_send(attr)
      end

      military_information_data
    rescue => e
      monitor.track_request(
        :error,
        'VA Profile military information prefill failed',
        'api.pensions.form_profile.military_prefill_error',
        call_location: caller_locations.first,
        exception: { message: e.message, backtrace: e.backtrace }
      )

      {}
    end

    # Returns a memoized instance of Logging::Monitor for tracking pensions form profile events.
    # The monitor is initialized with the identifier 'pensions-form-profile'.
    #
    # @return [Logging::Monitor] the monitor instance for pensions form profile logging
    def monitor
      @monitor ||= Logging::Monitor.new('pensions-form-profile')
    end
  end
end
