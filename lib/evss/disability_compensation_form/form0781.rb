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
        @sync_modern_0781_flow = form_content.dig('form526', 'syncModern0781Flow')
        @translated_forms = {}
      end

      # Merges the user data and performs the translation
      #
      # @return [Hash] The translated form(s) ready for submission
      #
      def translate
        return nil unless @form_content

        if @sync_modern_0781_flow
          @translated_forms['form0781v2'] = create_form_v2
        else
          # The pdf creation functionality is looking for a single street address
          # instead of a hash
          @form_content['incidents'].each do |incident|
            incident['incidentLocation'] = join_location(incident['incidentLocation']) if incident['incidentLocation']
          end

          incs0781a, incs0781 = split_incidents(@form_content['incidents'])

          @translated_forms['form0781'] = create_form(incs0781) if incs0781.present?
          @translated_forms['form0781a'] = create_form(incs0781a) if incs0781a.present?
        end

        @translated_forms
      end

      private

      def create_form(incidents)
        prepare_veteran_info.merge({
                                     'incidents' => incidents,
                                     'remarks' => @form_content['remarks'],
                                     'additionalIncidentText' => @form_content['additionalIncidentText'],
                                     'otherInformation' => @form_content['otherInformation']
                                   })
      end

      def create_form_v2
        events = @form_content['events'].nil? ? nil : sanitize_details(@form_content['events'])
        behavior_details = @form_content['behaviorsDetails'].nil? ? nil : sanitize_hash_values(@form_content['behaviorsDetails'])
        additional_info = @form_content['additionalInformation'].nil? ? nil : sanitize_text(@form_content['additionalInformation'])
        prepare_veteran_info.merge({
                                     'eventTypes' => @form_content['eventTypes'],
                                     'events' => events,
                                     'behaviors' => aggregate_behaviors,
                                     'behaviorsDetails' => behavior_details,
                                     'evidence' => aggregate_supporting_evidence,
                                     'treatmentNoneCheckbox' => @form_content['treatmentNoneCheckbox'],
                                     'treatmentProviders' => aggregate_treatment_providers,
                                     'treatmentProvidersDetails' => @form_content['treatmentProvidersDetails'],
                                     'optionIndicator' => @form_content['optionIndicator'],
                                     'additionalInformation' => additional_info
                                   })
      end

      def prepare_veteran_info
        {
          'vaFileNumber' => @user.ssn,
          'veteranSocialSecurityNumber' => @user.ssn,
          'veteranFullName' => full_name,
          'veteranDateOfBirth' => @user.birth_date,
          'email' => @phone_email['emailAddress'],
          'veteranPhone' => @phone_email['primaryPhone'],
          'veteranSecondaryPhone' => '', # No secondary phone available in 526 PreFill
          'veteranServiceNumber' => '' # No veteran service number available in 526 PreFill
        }
      end

      def aggregate_behaviors
        (@form_content['workBehaviors'] || {})
          .merge(@form_content['healthBehaviors'] || {})
          .merge(@form_content['otherBehaviors'] || {})
          .select { |_key, value| value }
      end

      def aggregate_supporting_evidence
        evidence = {}

        evidence.merge!(@form_content['supportingEvidenceReports'] || {})
        evidence.merge!(@form_content['supportingEvidenceRecords'] || {})
        evidence.merge!(@form_content['supportingEvidenceWitness'] || {})
        evidence.merge!(@form_content['supportingEvidenceOther'] || {})
        evidence.merge!('none' => @form_content['supportingEvidenceNoneCheckbox']&.[]('none') || false)

        if @form_content['supportingEvidenceUnlisted'].present?
          evidence['other'] = true
          evidence['otherDetails'] = @form_content['supportingEvidenceUnlisted']
        end

        evidence.select { |_key, value| value }
      end

      def aggregate_treatment_providers
        (@form_content['treatmentReceivedVaProvider'] || {})
          .merge(@form_content['treatmentReceivedNonVaProvider'] || {})
          .select { |_key, value| value }
      end

      def sanitize_text(string)
        string.gsub(/\n|\r/, ' ') # Replace each line break with a space
      end

      def sanitize_hash_values(hash)
        hash.transform_values { |value| sanitize_text(value) }
      end

      def sanitize_details(events)
        events.map do |event|
          if event.key?('details') && !event['details'].nil?
            event.merge('details' => sanitize_text(event['details']))
          else
            event
          end
        end
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
        ].compact_blank.join(', ')
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
