# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # Transforms a client 0781 form submission into the format expected by the EVSS service
    #
    # @param user [User] The current user
    # @param form_content [Hash] Hash of the parsed JSON submitted by the client
    #
    class Form0781
      def initialize(user, form_content)
        @user = user
        @phone_email = form_content.dig('form526', 'phoneAndEmail')
        @form_content = form_content.dig('form526', 'form0781')
        @translated_forms = {}
      end

      # Merges the user data and performs the translation
      #
      # @return [Hash] The translated form(s) ready for submission
      #
      def translate
        return nil unless @form_content

        # The pdf creation functionality is looking for a single street address
        # instead of a hash
        @form_content['incidents'].each do |incident|
          incident['incidentLocation'] = join_location(incident['incidentLocation']) if incident['incidentLocation']
        end

        incs0781a, incs0781 = split_incidents(@form_content['incidents'])

        @translated_forms['form0781'] = create_form(incs0781) if incs0781.present?
        @translated_forms['form0781a'] = create_form(incs0781a) if incs0781a.present?

        @translated_forms
      end

      private

      def create_form(incidents)
        {
          'vaFileNumber' => @user.ssn,
          'veteranSocialSecurityNumber' => @user.ssn,
          'veteranFullName' => full_name,
          'veteranDateOfBirth' => @user.birth_date,
          'email' => @phone_email['emailAddress'],
          'veteranPhone' => @phone_email['primaryPhone'],
          'veteranSecondaryPhone' => '', # No secondary phone available in 526 PreFill
          'veteranServiceNumber' => '', # No veteran service number available in 526 PreFill
          'incidents' => incidents,
          'remarks' => @form_content['remarks'],
          'additionalIncidentText' => @form_content['additionalIncidentText'],
          'otherInformation' => @form_content['otherInformation']
        }
      end

      def split_incidents(incidents)
        return nil if incidents.blank?
        incidents.partition { |incident| incident['personalAssault'] }
      end

      def join_location(location)
        [
          location['city'],
          location['state'],
          location['country'],
          location['additionalDetails']
        ].reject(&:blank?).join(', ')
      end

      def full_name
        {
          'first' => @user.first_name,
          'middle' => @user.middle_name,
          'last' => @user.last_name
        }
      end
    end
  end
end
