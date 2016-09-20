# frozen_string_literal: true
require 'ox'
require_relative 'message_builder'

module MVI
  module Messages
    # Builds an MVI SOAP XML message.
    #
    # = Usage
    # Call the .build passing in the candidate's given and family names, dob, and ssn.
    #
    # Example:
    #  dob = Time.new(1980, 1, 1).utc
    #  message = MVI::Messages::FindCandidateMessage.new(['John', 'William'], 'Smith', dob, '555-44-3333').to_xml
    #
    class FindCandidateMessage
      include MVI::Messages::MessageBuilder
      EXTENSION = 'PRPA_IN201305UV02'

      attr_reader :given_names, :family_name, :dob, :ssn

      validate :validate_types
      validates_format_of :ssn, with: /\d{3}-\d{2}-\d{4}/

      def initialize(given_names, family_name, dob, ssn)
        @given_names = given_names
        @family_name = family_name
        @dob = dob
        @ssn = ssn
      end

      def to_xml
        raise FindCandidateMessageError, errors.full_messages.join(', ') unless valid?
        super(EXTENSION, build_body)
      rescue => e
        Rails.logger.error "failed to build find candidate message: #{e.message}"
        raise
      end

      private

      def validate_types
        if !@given_names.is_a?(Array) || @given_names.any? { |i| !i.is_a? String }
          errors.add(:given_names, 'should be an array of Strings')
        end
        errors.add(:family_name, 'should be a String') unless @family_name.is_a?(String)
        errors.add(:dob, 'should be a Time object') unless @dob.is_a?(Time)
      end

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
      end

      def build_query_by_parameter
        el = element('queryByParameter')
        el << element('queryId', root: '1.2.840.114350.1.13.28.1.18.5.999', extension: '18204')
        el << element('statusCode', code: 'new')
        el << element('modifyCode', code: 'MVI.COMP1')
        el << element('initialValue', value: 1)
      end

      def build_parameter_list
        el = element('parameterList')
        el << build_living_subject_name
        el << build_living_subject_birth_time
        el << build_living_subject_id
      end

      def build_living_subject_name
        el = element('livingSubjectName')
        value = element('value', use: 'L')
        @given_names.each do |given_name|
          value << element('given', text!: given_name)
        end
        value << element('family', text!: @family_name)
        el << value
      end

      def build_living_subject_birth_time
        el = element('livingSubjectBirthTime')
        el << element('value', value: @dob.strftime('%Y%m%d'))
        el << element('semanticsText', text!: 'LivingSubject..birthTime')
      end

      def build_living_subject_id
        el = element('livingSubjectId')
        el << element('value', root: '2.16.840.1.113883.4.1', extention: @ssn)
        el << element('semanticsText', text!: 'SSN')
      end
    end
    class FindCandidateMessageError < MessageBuilderError
    end
  end
end
