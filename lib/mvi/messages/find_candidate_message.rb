require 'ox'
require_relative 'message_builder'

module MVI
  module Messages
    class FindCandidateMessage
      extend MVI::Messages::MessageBuilder
      EXTENSION = 'PRPA_IN201305UV02'.freeze

      class << self
        def build(first_name, last_name, dob, ssn)
          validate(dob, first_name, last_name, ssn)
          @message = idm(EXTENSION)
          header(EXTENSION)
          find_candidate_body(parameter_list(first_name, last_name, dob, ssn))
          doc << envelope_body(@message)
          Ox.dump(doc)
        end

        def validate(dob, first_name, last_name, ssn)
          raise ArgumentError.new('first and last name sould be Strings') unless [first_name, last_name].all? { |i| i.is_a? String }
          raise ArgumentError.new('dob should be a Time object') unless dob.is_a? Time
          raise ArgumentError.new('ssn should be of format \d{3}-\d{2}-\d{4}') unless ssn =~ /\d{3}-\d{2}-\d{4}/
        end

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
          el << element('queryId', root: '1.2.840.114350.1.13.28.1.18.5.999', extension: '18204')
          el << element('statusCode', code: 'new')
          el << element('modifyCode', code: 'MVI.COMP1')
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
end
