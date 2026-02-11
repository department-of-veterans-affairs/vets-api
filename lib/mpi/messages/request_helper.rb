# frozen_string_literal: true

module MPI
  module Messages
    class RequestHelper
      class << self
        def build_identifier(identifier:, root:)
          element('id', root:, extension: identifier)
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

        def build_represented_organization(edipi:)
          orchestrated_search_element = element('representedOrganization', determinerCode: 'INSTANCE', classCode: 'ORG')
          orchestrated_search_element << build_identifier(identifier: "dslogon.#{edipi}",
                                                          root: MPI::Constants::VA_ROOT_OID)
          orchestrated_search_element << element('code', code: Time.now.utc.strftime('%Y-%m-%d %H:%M:%S'))
          orchestrated_search_element << text_element('desc', 'vagov')
          ip_address = Socket.ip_address_list.find { |ip| ip.ipv4? && !ip.ipv4_loopback? }.ip_address
          orchestrated_search_element << element('telecom', value: ip_address)
          orchestrated_search_element
        end

        def build_query_by_parameter(search_type:, view_type: MPI::Constants::PRIMARY_VIEW)
          query_element = element('queryByParameter')
          query_element << element('queryId', root: '1.2.840.114350.1.13.28.1.18.5.999', extension: '18204')
          query_element << element('statusCode', code: 'new')
          query_element << element('modifyCode', code: search_type)
          query_element << element('initialQuantity', value: 1)
          query_element << element('responseElementGroupId', extension: view_type, root: MPI::Constants::VA_ROOT_OID)
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
          build_identifier(identifier: ssn, root: '2.16.840.1.113883.777.999')
        end

        def build_subject_element
          element('subject', typeCode: 'SUBJ')
        end

        def build_registration_event_element
          element('registrationEvent', classCode: 'REG', moodCode: 'EVN')
        end

        def build_id_null_flavor(type:)
          element('id', nullFlavor: type)
        end

        def build_status_code
          element('statusCode', code: 'active')
        end

        def build_subject_1_element
          element('subject1', typeCode: 'SBJ')
        end

        def build_patient_element
          element('patient', classCode: 'PAT')
        end

        def build_patient_person_element
          element('patientPerson')
        end

        def build_patient_person_name(given_names:, family_name:)
          name_value = element('name', use: 'L')
          given_names.each do |given_name|
            name_value << text_element('given', given_name)
          end
          name_value << text_element('family', family_name)
        end

        def build_telecom(type:, value:)
          element('telecom', use: type, value:)
        end

        def build_patient_person_birth_date(birth_date:)
          element('birthTime', value: Date.parse(birth_date)&.strftime('%Y%m%d'))
        end

        def build_patient_person_address(street:, state:, city:, postal_code:, country:)
          address_element = element('addr', use: 'HP')
          address_element << text_element('streetAddressLine', street)
          address_element << text_element('city', city)
          address_element << text_element('state', state)
          address_element << text_element('postalCode', postal_code)
          address_element << text_element('country', country)
          address_element
        end

        def build_patient_identifier(identifier:, root:, class_code:)
          ssn_element = element('asOtherIDs', classCode: class_code)
          ssn_element << build_identifier(identifier:, root:)
          ssn_element << build_scoping_organization(root:)
          ssn_element
        end

        def build_patient_person_proxy_add
          proxy_add_element = element('asOtherIDs', classCode: 'PAT')
          proxy_add_element << build_identifier(identifier: 'PROXY_ADD^PI^200VBA^USVBA',
                                                root: MPI::Constants::VA_ROOT_OID)
          proxy_add_element << build_scoping_organization(root: MPI::Constants::VA_ROOT_OID, orchestration: true)
          proxy_add_element
        end

        def build_provider_organization
          provider_organization = element('providerOrganization', determinerCode: 'INSTANCE', classCode: 'ORG')
          provider_organization << element('id', root: '2.16.840.1.113883.3.933')
          provider_organization << text_element('name', 'Good Health Clinic')
          provider_organization << build_contact_party
          provider_organization
        end

        def build_custodian
          custodian = element('custodian', typeCode: 'CST')
          custodian << build_assigned_entity
          custodian
        end

        def build_vba_orchestration
          vba_element = element('otherIDsScopingOrganization')
          vba_element << element('value', extension: 'VBA', root: MPI::Constants::VA_ROOT_OID)
          vba_element << text_element('semanticsText', 'MVI.ORCHESTRATION')
          vba_element
        end

        def build_control_act_process_element
          element('controlActProcess', classCode: 'CACT', moodCode: 'EVN')
        end

        def build_code(code:)
          element('code', code:, codeSystem: '2.16.840.1.113883.1.6')
        end

        def build_parameter_list_element
          element('parameterList')
        end

        private

        def build_scoping_organization(root:, orchestration: nil)
          scoping_organization = element('scopingOrganization', determinerCode: 'INSTANCE', classCode: 'ORG')
          scoping_organization << element('id', root:)
          scoping_organization << text_element('name', 'MVI.ORCHESTRATION') if orchestration
          scoping_organization
        end

        def build_assigned_entity
          assigned_entity = element('assignedEntity', classCode: 'ASSIGNED')
          assigned_entity << element('id', root: '2.16.840.1.113883.3.933')
          assigned_entity << build_assigned_organization
          assigned_entity
        end

        def build_assigned_organization
          assigned_organization = element('assignedOrganization', determinerCode: 'INSTANCE', classCode: 'ORG')
          assigned_organization << text_element('name', 'Good Health Clinic')
          assigned_organization
        end

        def build_contact_party
          contact_party = element('contactParty', classCode: 'CON')
          contact_party << element('telecom', value: '3425558394')
          contact_party
        end

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
