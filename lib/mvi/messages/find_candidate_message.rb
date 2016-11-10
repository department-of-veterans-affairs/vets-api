# frozen_string_literal: true
require 'ox'
require_relative 'message_builder'

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
    class FindCandidateMessage
      include MVI::Messages::MessageBuilder
      EXTENSION = 'PRPA_IN201305UV02'

      attr_reader :given_names, :family_name, :birth_date, :ssn, :gender

      def initialize(given_names, family_name, birth_date, ssn, gender = nil)
        @given_names = given_names
        @family_name = family_name
        @birth_date = birth_date
        @ssn = ssn
        @gender = gender
      end

      def to_xml
        super(EXTENSION, build_body)
      rescue => e
        Rails.logger.error "failed to build find candidate message: #{e.message}"
        raise
      end

      def digest
        Digest::SHA256.base64digest(instance_values.flatten(2).join)
      end

      private

      def build_body
        control_act_process = build_control_act_process
        query_by_parameter = build_query_by_parameter
        query_by_parameter << build_parameter_list
        control_act_process << query_by_parameter
        control_act_process
      end

      def build_control_act_process
        el = element('controlActProcess', classCode: 'CACT', moodCode: 'EVN')
        el << element('code', code: 'PRPA_TE201305UV02', codeSystem: '2.16.840.1.113883.1.6')
        el << build_data_enterer
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
        el << assigned_person
      end

      def build_query_by_parameter
        el = element('queryByParameter')
        el << element('queryId', root: '1.2.840.114350.1.13.28.1.18.5.999', extension: '18204')
        el << element('statusCode', code: 'new')
        el << element('modifyCode', code: 'MVI.COMP1')
        el << element('initialQuantity', value: 1)
      end

      def build_parameter_list
        el = element('parameterList')
        el << build_gender
        el << build_living_subject_birth_time
        el << build_living_subject_id
        el << build_living_subject_name
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
      end

      def build_living_subject_birth_time
        el = element('livingSubjectBirthTime')
        el << element('value', value: Date.parse(@birth_date)&.strftime('%Y%m%d'))
        el << element('semanticsText', text!: 'Date of Birth')
      end

      def build_living_subject_id
        el = element('livingSubjectId')
        el << element('value', root: '2.16.840.1.113883.4.1', extension: @ssn)
        el << element('semanticsText', text!: 'SSN')
      end

      def build_gender
        el = element('livingSubjectAdministrativeGender')
        el << element('value', code: @gender)
        el << element('semanticsText', text!: 'Gender')
      end
    end
    class FindCandidateMessageError < MessageBuilderError
    end
  end
end
