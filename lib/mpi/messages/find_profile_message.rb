# frozen_string_literal: true

require_relative 'find_profile_message_helpers'

module MVI
  module Messages
    # Builds an MVI SOAP XML message.
    #
    # = Usage
    # Call the .build passing in the candidate's given and family names, birth_date, and ssn.
    #
    # Example:
    #  birth_date = Time.new(1980, 1, 1).utc
    #  message = MVI::Messages::FindCandidateMessage.new(['John', 'William'], 'Smith', birth_date, '555-44-3333').to_xml
    #
    class FindProfileMessage
      include FindProfileMessageHelpers
      attr_reader :given_names, :family_name, :birth_date, :ssn, :gender

      def initialize(profile, orch_search = false, edipi = nil)
        # gender is optional and will default to nil if it DNE
        raise ArgumentError, 'wrong number of arguments' unless %i[
          given_names
          last_name
          birth_date
          ssn
        ].all? { |k| profile.key? k }

        @given_names = profile[:given_names]
        @family_name = profile[:last_name]
        @birth_date = profile[:birth_date]
        @ssn = profile[:ssn]
        @gender = profile[:gender]
        @orch_search = orch_search
        @edipi = edipi
      end

      private

      def build_control_act_process
        el = element('controlActProcess', classCode: 'CACT', moodCode: 'EVN')
        el << element('code', code: 'PRPA_TE201305UV02', codeSystem: '2.16.840.1.113883.1.6')
        el << build_data_enterer
        el
      end

      def build_data_enterer
        el = element('dataEnterer', typeCode: 'ENT', contextControlCode: 'AP')
        assigned_person = element('assignedPerson', classCode: 'ASSIGNED')
        assigned_person << element('id', extension: @ssn, root: '2.16.840.1.113883.777.999')
        assigned_person_instance = element('assignedPerson', classCode: 'PSN', determinerCode: 'INSTANCE')
        name = element('name')
        @given_names.each do |given_name|
          name << element('given', text!: given_name)
        end
        name << element('family', text!: @family_name)
        assigned_person_instance << name
        assigned_person << assigned_person_instance
        assigned_person << build_orchestrated_search if @orch_search
        el << assigned_person
        el
      end

      def build_parameter_list
        el = element('parameterList')
        el << build_gender if @gender.present?
        el << build_living_subject_birth_time
        el << build_living_subject_id
        el << build_living_subject_name
        el << build_vba_orchestration if Settings.mvi.vba_orchestration
        el
      end

      def build_living_subject_name
        el = element('livingSubjectName')
        value = element('value', use: 'L')
        @given_names.each do |given_name|
          value << element('given', text!: given_name)
        end
        value << element('family', text!: @family_name)
        el << value
        el << element('semanticsText', text!: 'Legal Name')
        el
      end

      def build_living_subject_birth_time
        el = element('livingSubjectBirthTime')
        el << element('value', value: Date.parse(@birth_date)&.strftime('%Y%m%d'))
        el << element('semanticsText', text!: 'Date of Birth')
        el
      end

      def build_living_subject_id
        el = element('livingSubjectId')
        el << element('value', root: '2.16.840.1.113883.4.1', extension: @ssn)
        el << element('semanticsText', text!: 'SSN')
        el
      end

      def build_gender
        el = element('livingSubjectAdministrativeGender')
        el << element('value', code: @gender)
        el << element('semanticsText', text!: 'Gender')
        el
      end

      def build_orchestrated_search
        # For BGS, they require a the clients ip address for the telecom value in the xml payload
        # This is to trace the request all the way from BGS back to vets-api if the need arises
        ip_address = Socket.ip_address_list.find { |ip| ip.ipv4? && !ip.ipv4_loopback? }.ip_address
        el = element('representedOrganization', determinerCode: 'INSTANCE', classCode: 'ORG')
        el << element('id', root: '2.16.840.1.113883.4.349', extension: "dslogon.#{@edipi}")
        el << element('code', code: Time.now.utc.strftime('%Y-%m-%d %H:%M:%S'))
        el << element('desc', text!: 'vagov')
        el << element('telecom', value: ip_address)
        el
      end
    end
  end
end
