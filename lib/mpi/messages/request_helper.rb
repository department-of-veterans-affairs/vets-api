# frozen_string_literal: true

module MPI
  module Messages
    class RequestHelper
      class << self
        def build_identifier(identifier:)
          element('id', root: '2.16.840.1.113883.4.349', extension: identifier)
        end

        def build_edipi_identifier(edipi:)
          element('id', root: '2.16.840.1.113883.3.42.10001.100001.12', extension: edipi)
        end

        def build_name(given_names:, family_name:)
          name_value = element('value', use: 'L')
          given_names.each do |given_name|
            name_value << text_element('given', given_name)
          end
          name_value << text_element('family', family_name)
          subject_name = element('livingSubjectName')
          subject_name << name_value
          subject_name << text_element('semanticsText', 'Legal Name')
          subject_name
        end

        def build_birth_date(birth_date:)
          birth_time_element = element('livingSubjectBirthTime')
          birth_time_element << element('value', value: Date.parse(birth_date)&.strftime('%Y%m%d'))
          birth_time_element << text_element('semanticsText', 'Date of Birth')
          birth_time_element
        end

        def build_ssn(ssn:)
          ssn_element = element('livingSubjectId')
          ssn_element << element('value', root: '2.16.840.1.113883.4.1', extension: ssn)
          ssn_element << text_element('semanticsText', 'SSN')
          ssn_element
        end

        def build_gender(gender:)
          gender_element = element('livingSubjectAdministrativeGender')
          gender_element << element('value', code: gender)
          gender_element << text_element('semanticsText', 'Gender')
          gender_element
        end

        def build_orchestrated_search(edipi:)
          orchestrated_search_element = element('representedOrganization', determinerCode: 'INSTANCE', classCode: 'ORG')
          orchestrated_search_element << element('id', root: '2.16.840.1.113883.4.349', extension: "dslogon.#{edipi}")
          orchestrated_search_element << element('code', code: Time.now.utc.strftime('%Y-%m-%d %H:%M:%S'))
          orchestrated_search_element << text_element('desc', 'vagov')
          ip_address = Socket.ip_address_list.find { |ip| ip.ipv4? && !ip.ipv4_loopback? }.ip_address
          orchestrated_search_element << element('telecom', value: ip_address)
          orchestrated_search_element
        end

        def build_query_by_parameter(search_type:)
          query_element = element('queryByParameter')
          query_element << element('queryId', root: '1.2.840.114350.1.13.28.1.18.5.999', extension: '18204')
          query_element << element('statusCode', code: 'new')
          query_element << element('modifyCode', code: search_type)
          query_element << element('initialQuantity', value: 1)
          query_element
        end

        def build_assigned_person_instance(given_names:, family_name:)
          name_element = element('name')
          given_names.each do |given_name|
            name_element << text_element('given', given_name)
          end
          name_element << text_element('family', family_name)
          assigned_person_instance = element('assignedPerson', classCode: 'PSN', determinerCode: 'INSTANCE')
          assigned_person_instance << name_element
          assigned_person_instance
        end

        def build_data_enterer_element
          element('dataEnterer', typeCode: 'ENT', contextControlCode: 'AP')
        end

        def build_assigned_person_element
          element('assignedPerson', classCode: 'ASSIGNED')
        end

        def build_assigned_person_ssn(ssn:)
          element('id', extension: ssn, root: '2.16.840.1.113883.777.999')
        end

        def build_vba_orchestration
          vba_element = element('otherIDsScopingOrganization')
          vba_element << element('value', extension: 'VBA', root: '2.16.840.1.113883.4.349')
          vba_element << text_element('semanticsText', 'MVI.ORCHESTRATION')
          vba_element
        end

        def build_control_act_process
          control_act_element = element('controlActProcess', classCode: 'CACT', moodCode: 'EVN')
          control_act_element << element('code', code: 'PRPA_TE201305UV02', codeSystem: '2.16.840.1.113883.1.6')
          control_act_element
        end

        def build_parameter_list_element
          element('parameterList')
        end

        private

        def element(name, attributes = {})
          element = Ox::Element.new(name)
          attributes.each { |key, value| element[key] = value }
          element
        end

        def text_element(name, text)
          element = Ox::Element.new(name)
          element.replace_text(text)
          element
        end
      end
    end
  end
end
