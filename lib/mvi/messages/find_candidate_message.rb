require 'ox'
require_relative 'message_builder'

module MVI
  module Messages
    class FindCandidateMessage
      include MVI::Messages::MessageBuilder
      EXTENSION = 'PRPA_IN201305UV02'.freeze

      def build(vcid, first_name, last_name, dob, ssn)
        @message = xml_tag(EXTENSION)
        header(vcid, EXTENSION)
        find_candidate_body(parameter_list(first_name, last_name, dob, ssn))
        @doc << @message
        Ox.dump(@doc)
      end

      private

      def find_candidate_body(parameter_list)
        control_act_process = control_act_process()
        query_by_parameter = query_by_parameter()
        query_by_parameter << parameter_list
        control_act_process << query_by_parameter
        @message << control_act_process
      rescue => e
        Rails.logger.error e.message, backtrace: e.backtrace
      end

      def query_by_parameter
        el = element('queryByParameter')
        el << element('queryId', root: '2.16.840.1.113883.3.933', extension: '18204')
        el << element('statusCode', code: 'new')
        el << element('initialValue', value: 1)
        el
      end

      def parameter_list(first_name, last_name, dob, ssn)
        el = element('parameterList')
        el << living_subject_name(first_name, last_name)
        el << living_subject_birth_time(dob)
        el << living_subject_id(ssn)
        el
      end

      def control_act_process
        el = element('controlActProcess', classCode: 'CACT', moodCode: 'EVN')
        el << element('code', code: 'PRPA_TE201305UV02', codeSystem: '2.16.840.1.113883.1.6')
        el
      end

      def living_subject_name(first_name, last_name)
        el = element('livingSubjectName')
        value = element('value', use: 'L')
        value << element('given', text!: first_name)
        value << element('family', text!: last_name)
        el << value
      end

      def living_subject_birth_time(dob)
        el = element('livingSubjectBirthTime')
        el << element('value', value: dob.strftime('%Y%m%d'))
        el << element('semanticsText', text!: 'LivingSubject..birthTime')
        el
      end

      def living_subject_id(ssn)
        el = element('livingSubjectId')
        el << element('value', root: '2.16.840.1.113883.4.1', extention: ssn)
        el << element('semanticsText', text!: 'SSN')
        el
      end
    end
  end
end
