# frozen_string_literal: true
require 'ox'
require_relative 'message_builder'

module MVI
  module Messages
    # Builds an MVI SOAP XML message.
    #
    # = Usage
    # Call the .build passing in the candidate's first and last name, dob, and ssn.
    #
    # Example:
    #  dob = Time.new(1980, 1, 1).utc
    #  message = MVI::Messages::FindCandidateMessage.new.build('John', 'Smith', dob, '555-44-3333')
    #
    class FindCandidateMessage
      include MVI::Messages::MessageBuilder
      EXTENSION = 'PRPA_IN201305UV02'

      def build(first_name, last_name, dob, ssn)
        validate(dob, first_name, last_name, ssn)
        header(EXTENSION)
        body(build_parameter_list(first_name, last_name, dob, ssn))
        @doc << envelope_body(@message)
        Ox.dump(@doc)
      rescue => e
        Rails.logger.error "failed to build find candidate message: #{e.message}"
        raise
      end

      private

      def validate(dob, first_name, last_name, ssn)
        raise ArgumentError, 'names should be Strings' unless [first_name, last_name].all? { |i| i.is_a? String }
        raise ArgumentError, 'dob should be a Time object' unless dob.is_a? Time
        raise ArgumentError, 'ssn should be of format \d{3}-\d{2}-\d{4}' unless ssn =~ /\d{3}-\d{2}-\d{4}/
      end

      def body(parameter_list)
        control_act_process = build_control_act_process
        query_by_parameter = build_query_by_parameter
        query_by_parameter << parameter_list
        control_act_process << query_by_parameter
        @message << control_act_process
      end

      def build_query_by_parameter
        el = element('queryByParameter')
        el << element('queryId', root: '1.2.840.114350.1.13.28.1.18.5.999', extension: '18204')
        el << element('statusCode', code: 'new')
        el << element('modifyCode', code: 'MVI.COMP1')
        el << element('initialValue', value: 1)
      end

      def build_parameter_list(first_name, last_name, dob, ssn)
        el = element('parameterList')
        el << build_living_subject_name(first_name, last_name)
        el << build_living_subject_birth_time(dob)
        el << build_living_subject_id(ssn)
      end

      def build_control_act_process
        el = element('controlActProcess', classCode: 'CACT', moodCode: 'EVN')
        el << element('code', code: 'PRPA_TE201305UV02', codeSystem: '2.16.840.1.113883.1.6')
      end

      def build_living_subject_name(first_name, last_name)
        el = element('livingSubjectName')
        value = element('value', use: 'L')
        value << element('given', text!: first_name)
        value << element('family', text!: last_name)
        el << value
      end

      def build_living_subject_birth_time(dob)
        el = element('livingSubjectBirthTime')
        el << element('value', value: dob.strftime('%Y%m%d'))
        el << element('semanticsText', text!: 'LivingSubject..birthTime')
      end

      def build_living_subject_id(ssn)
        el = element('livingSubjectId')
        el << element('value', root: '2.16.840.1.113883.4.1', extention: ssn)
        el << element('semanticsText', text!: 'SSN')
      end
    end
  end
end
