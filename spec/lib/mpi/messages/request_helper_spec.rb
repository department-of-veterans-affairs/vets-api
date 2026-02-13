# frozen_string_literal: true

require 'rails_helper'
require 'mpi/messages/request_helper'

describe MPI::Messages::RequestHelper do
  describe '.build_identifier' do
    subject { described_class.build_identifier(identifier:, root:) }

    let(:identifier) { 'some-identifier' }
    let(:root) { 'some-root' }
    let(:expected_element) do
      element = Ox::Element.new('id')
      element[:root] = root
      element[:extension] = identifier
      element
    end

    it 'builds an Ox element with identifier attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_name' do
    subject { described_class.build_name(given_names:, family_name:) }

    let(:first_given_name) { 'some-given-name' }
    let(:second_given_name) { 'some-other-given-name' }
    let(:given_names) { [first_given_name, second_given_name] }
    let(:family_name) { 'some-family-name' }
    let(:expected_first_given_text_element) do
      element = Ox::Element.new('given')
      element.replace_text(first_given_name)
      element
    end
    let(:expected_second_given_text_element) do
      element = Ox::Element.new('given')
      element.replace_text(second_given_name)
      element
    end
    let(:expected_family_text_element) do
      element = Ox::Element.new('family')
      element.replace_text(family_name)
      element
    end
    let(:expected_name_value_element) do
      element = Ox::Element.new('value')
      element[:use] = 'L'
      element << expected_first_given_text_element
      element << expected_second_given_text_element
      element << expected_family_text_element
      element
    end
    let(:expected_semantics_text_element) do
      element = Ox::Element.new('semanticsText')
      element.replace_text('Legal Name')
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('livingSubjectName')
      element << expected_name_value_element
      element << expected_semantics_text_element
      element
    end

    it 'builds an Ox element with name attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_birth_date' do
    subject { described_class.build_birth_date(birth_date:) }

    let(:birth_date) { '1-1-2020' }
    let(:expected_birth_date) { Date.parse(birth_date)&.strftime('%Y%m%d') }
    let(:expected_value_element) do
      element = Ox::Element.new('value')
      element[:value] = expected_birth_date
      element
    end
    let(:expected_semantics_text_element) do
      element = Ox::Element.new('semanticsText')
      element.replace_text('Date of Birth')
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('livingSubjectBirthTime')
      element << expected_value_element
      element << expected_semantics_text_element
      element
    end

    it 'builds an Ox element with birth date attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_ssn' do
    subject { described_class.build_ssn(ssn:) }

    let(:ssn) { 'some-ssn' }
    let(:expected_value_element) do
      element = Ox::Element.new('value')
      element[:root] = '2.16.840.1.113883.4.1'
      element[:extension] = ssn
      element
    end
    let(:expected_semantics_text_element) do
      element = Ox::Element.new('semanticsText')
      element.replace_text('SSN')
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('livingSubjectId')
      element << expected_value_element
      element << expected_semantics_text_element
      element
    end

    it 'builds an Ox element with ssn attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_gender' do
    subject { described_class.build_gender(gender:) }

    let(:gender) { 'some-gender' }
    let(:expected_value_element) do
      element = Ox::Element.new('value')
      element[:code] = gender
      element
    end
    let(:expected_semantics_text_element) do
      element = Ox::Element.new('semanticsText')
      element.replace_text('Gender')
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('livingSubjectAdministrativeGender')
      element << expected_value_element
      element << expected_semantics_text_element
      element
    end

    it 'builds an Ox element with gender attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_represented_organization' do
    subject { described_class.build_represented_organization(edipi:) }

    before { Timecop.freeze }

    after { Timecop.return }

    let(:edipi) { 'some-edipi' }
    let(:expected_id_element) do
      element = Ox::Element.new('id')
      element[:root] = MPI::Constants::VA_ROOT_OID
      element[:extension] = "dslogon.#{edipi}"
      element
    end
    let(:expected_current_time_element) do
      element = Ox::Element.new('code')
      element[:code] = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
      element
    end
    let(:expected_vagov_text_element) do
      element = Ox::Element.new('desc')
      element.replace_text('vagov')
      element
    end
    let(:expected_ip_address) { Socket.ip_address_list.find { |ip| ip.ipv4? && !ip.ipv4_loopback? }.ip_address }
    let(:expected_telecom_element) do
      element = Ox::Element.new('telecom')
      element[:value] = expected_ip_address
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('representedOrganization')
      element[:determinerCode] = 'INSTANCE'
      element[:classCode] = 'ORG'
      element << expected_id_element
      element << expected_current_time_element
      element << expected_vagov_text_element
      element << expected_telecom_element
      element
    end

    it 'builds an Ox element with orchestrated search attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_query_by_parameter' do
    subject { described_class.build_query_by_parameter(search_type:) }

    let(:search_type) { 'some-search-type' }
    let(:expected_query_id_element) do
      element = Ox::Element.new('queryId')
      element[:root] = '1.2.840.114350.1.13.28.1.18.5.999'
      element[:extension] = '18204'
      element
    end
    let(:expected_status_code_element) do
      element = Ox::Element.new('statusCode')
      element[:code] = 'new'
      element
    end
    let(:expected_modify_code_element) do
      element = Ox::Element.new('modifyCode')
      element[:code] = search_type
      element
    end
    let(:expected_initial_quantity_element) do
      element = Ox::Element.new('initialQuantity')
      element[:value] = 1
      element
    end
    let(:expected_response_element_group_id_element) do
      element = Ox::Element.new('responseElementGroupId')
      element[:extension] = MPI::Constants::PRIMARY_VIEW
      element[:root] = MPI::Constants::VA_ROOT_OID
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('queryByParameter')
      element << expected_query_id_element
      element << expected_status_code_element
      element << expected_modify_code_element
      element << expected_initial_quantity_element
      element << expected_response_element_group_id_element
      element
    end

    it 'builds an Ox element with query by parameter attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_assigned_person_instance' do
    subject { described_class.build_assigned_person_instance(given_names:, family_name:) }

    let(:first_given_name) { 'some-given-name' }
    let(:second_given_name) { 'some-other-given-name' }
    let(:given_names) { [first_given_name, second_given_name] }
    let(:family_name) { 'some-family-name' }
    let(:expected_first_given_text_element) do
      element = Ox::Element.new('given')
      element.replace_text(first_given_name)
      element
    end
    let(:expected_second_given_text_element) do
      element = Ox::Element.new('given')
      element.replace_text(second_given_name)
      element
    end
    let(:expected_family_text_element) do
      element = Ox::Element.new('family')
      element.replace_text(family_name)
      element
    end
    let(:expected_name_element) do
      element = Ox::Element.new('name')
      element << expected_first_given_text_element
      element << expected_second_given_text_element
      element << expected_family_text_element
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('assignedPerson')
      element[:classCode] = 'PSN'
      element[:determinerCode] = 'INSTANCE'
      element << expected_name_element
      element
    end

    it 'builds an Ox element with assigned person instance' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_data_enterer_element' do
    subject { described_class.build_data_enterer_element }

    let(:expected_element) do
      element = Ox::Element.new('dataEnterer')
      element[:typeCode] = 'ENT'
      element[:contextControlCode] = 'AP'
      element
    end

    it 'builds an Ox element with data enterer element' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_assigned_person_element' do
    subject { described_class.build_assigned_person_element }

    let(:expected_element) do
      element = Ox::Element.new('assignedPerson')
      element[:classCode] = 'ASSIGNED'
      element
    end

    it 'builds an Ox element with assigned person element' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_assigned_person_ssn' do
    subject { described_class.build_assigned_person_ssn(ssn:) }

    let(:ssn) { 'some-ssn' }
    let(:expected_element) do
      element = Ox::Element.new('id')
      element[:root] = '2.16.840.1.113883.777.999'
      element[:extension] = ssn
      element
    end

    it 'builds an Ox element with ssn attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_subject_element' do
    subject { described_class.build_subject_element }

    let(:expected_element) do
      element = Ox::Element.new('subject')
      element[:typeCode] = 'SUBJ'
      element
    end

    it 'builds an Ox element with subject element' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_registration_event_element' do
    subject { described_class.build_registration_event_element }

    let(:expected_element) do
      element = Ox::Element.new('registrationEvent')
      element[:classCode] = 'REG'
      element[:moodCode] = 'EVN'
      element
    end

    it 'builds an Ox element with registration event element' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_id_null_flavor' do
    subject { described_class.build_id_null_flavor(type:) }

    let(:type) { 'some-type' }
    let(:expected_element) do
      element = Ox::Element.new('id')
      element[:nullFlavor] = type
      element
    end

    it 'builds an Ox element with id null flavor element' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_status_code' do
    subject { described_class.build_status_code }

    let(:expected_element) do
      element = Ox::Element.new('statusCode')
      element[:code] = 'active'
      element
    end

    it 'builds an Ox element with status code element' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_subject_1_element' do
    subject { described_class.build_subject_1_element }

    let(:expected_element) do
      element = Ox::Element.new('subject1')
      element[:typeCode] = 'SBJ'
      element
    end

    it 'builds an Ox element with subject 1 element' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_patient_element' do
    subject { described_class.build_patient_element }

    let(:expected_element) do
      element = Ox::Element.new('patient')
      element[:classCode] = 'PAT'
      element
    end

    it 'builds an Ox element with patient person element' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_patient_person_element' do
    subject { described_class.build_patient_person_element }

    let(:expected_element) do
      element = Ox::Element.new('patientPerson')
      element
    end

    it 'builds an Ox element with patient person element' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_patient_person_name' do
    subject { described_class.build_patient_person_name(given_names:, family_name:) }

    let(:first_given_name) { 'some-given-name' }
    let(:second_given_name) { 'some-other-given-name' }
    let(:given_names) { [first_given_name, second_given_name] }
    let(:family_name) { 'some-family-name' }
    let(:expected_first_given_text_element) do
      element = Ox::Element.new('given')
      element.replace_text(first_given_name)
      element
    end
    let(:expected_second_given_text_element) do
      element = Ox::Element.new('given')
      element.replace_text(second_given_name)
      element
    end
    let(:expected_family_text_element) do
      element = Ox::Element.new('family')
      element.replace_text(family_name)
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('name')
      element[:use] = 'L'
      element << expected_first_given_text_element
      element << expected_second_given_text_element
      element << expected_family_text_element
      element
    end

    it 'builds an Ox element with name attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_telecom' do
    subject { described_class.build_telecom(type:, value: email) }

    let(:email) { 'some-email' }
    let(:type) { 'EMAIL' }
    let(:expected_element) do
      element = Ox::Element.new('telecom')
      element[:use] = type
      element[:value] = email
      element
    end

    it 'builds an Ox element with email attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_patient_person_birth_date' do
    subject { described_class.build_patient_person_birth_date(birth_date:) }

    let(:birth_date) { '19201030' }
    let(:expected_element) do
      element = Ox::Element.new('birthTime')
      element[:value] = Date.parse(birth_date)&.strftime('%Y%m%d')
      element
    end

    it 'builds an Ox element with birth date attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_patient_person_address' do
    subject do
      described_class.build_patient_person_address(street:,
                                                   state:,
                                                   city:,
                                                   postal_code:,
                                                   country:)
    end

    let(:street) { 'some-street' }
    let(:state) { 'some-state' }
    let(:city) { 'some-city' }
    let(:postal_code) { 'some-postal-code' }
    let(:country) { 'some-country' }

    let(:expected_scoping_id) do
      element = Ox::Element.new('id')
      element[:root] = root
      element
    end

    let(:expected_city) do
      element = Ox::Element.new('city')
      element.replace_text(city)
      element
    end
    let(:expected_state) do
      element = Ox::Element.new('state')
      element.replace_text(state)
      element
    end
    let(:expected_postal_code) do
      element = Ox::Element.new('postalCode')
      element.replace_text(postal_code)
      element
    end
    let(:expected_street) do
      element = Ox::Element.new('streetAddressLine')
      element.replace_text(street)
      element
    end
    let(:expected_country) do
      element = Ox::Element.new('country')
      element.replace_text(country)
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('addr')
      element[:use] = 'HP'
      element << expected_street
      element << expected_city
      element << expected_state
      element << expected_postal_code
      element << expected_country
      element
    end

    it 'builds an Ox element with patient address attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_patient_identifier' do
    subject { described_class.build_patient_identifier(identifier:, root:, class_code:) }

    let(:identifier) { 'some-identifier' }
    let(:root) { 'some-root' }
    let(:class_code) { 'some-class-code' }

    let(:expected_scoping_id) do
      element = Ox::Element.new('id')
      element[:root] = root
      element
    end

    let(:expected_scoping_organization) do
      element = Ox::Element.new('scopingOrganization')
      element[:determinerCode] = 'INSTANCE'
      element[:classCode] = 'ORG'
      element << expected_scoping_id
      element
    end
    let(:expected_id) do
      element = Ox::Element.new('id')
      element[:extension] = identifier
      element[:root] = root
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('asOtherIDs')
      element[:classCode] = class_code
      element << expected_id
      element << expected_scoping_organization
      element
    end

    it 'builds an Ox element with patient identifier attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_patient_person_proxy_add' do
    subject { described_class.build_patient_person_proxy_add }

    let(:identifier) { 'PROXY_ADD^PI^200VBA^USVBA' }
    let(:root) { MPI::Constants::VA_ROOT_OID }
    let(:class_code) { 'PAT' }

    let(:expected_scoping_id) do
      element = Ox::Element.new('id')
      element[:root] = root
      element
    end
    let(:expected_scoping_text) do
      element = Ox::Element.new('name')
      element.replace_text('MVI.ORCHESTRATION')
      element
    end
    let(:expected_scoping_organization) do
      element = Ox::Element.new('scopingOrganization')
      element[:determinerCode] = 'INSTANCE'
      element[:classCode] = 'ORG'
      element << expected_scoping_id
      element << expected_scoping_text
      element
    end
    let(:expected_id) do
      element = Ox::Element.new('id')
      element[:extension] = identifier
      element[:root] = root
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('asOtherIDs')
      element[:classCode] = class_code
      element << expected_id
      element << expected_scoping_organization
      element
    end

    it 'builds an Ox element with patient person proxy add attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_provider_organization' do
    subject { described_class.build_provider_organization }

    let(:expected_telecom) do
      element = Ox::Element.new('telecom')
      element[:value] = '3425558394'
      element
    end
    let(:expected_contact_party) do
      element = Ox::Element.new('contactParty')
      element[:classCode] = 'CON'
      element << expected_telecom
      element
    end
    let(:expected_id) do
      element = Ox::Element.new('id')
      element[:root] = '2.16.840.1.113883.3.933'
      element
    end
    let(:expected_text_element) do
      element = Ox::Element.new('name')
      element.replace_text('Good Health Clinic')
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('providerOrganization')
      element[:determinerCode] = 'INSTANCE'
      element[:classCode] = 'ORG'
      element << expected_id
      element << expected_text_element
      element << expected_contact_party
      element
    end

    it 'builds an Ox element with provider organization attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_custodian' do
    subject { described_class.build_custodian }

    let(:expected_text_element) do
      element = Ox::Element.new('name')
      element.replace_text('Good Health Clinic')
      element
    end
    let(:expected_assigned_organization) do
      element = Ox::Element.new('assignedOrganization')
      element[:determinerCode] = 'INSTANCE'
      element[:classCode] = 'ORG'
      element << expected_text_element
      element
    end
    let(:expected_id) do
      element = Ox::Element.new('id')
      element[:root] = '2.16.840.1.113883.3.933'
      element
    end
    let(:expected_assigned_entity) do
      element = Ox::Element.new('assignedEntity')
      element[:classCode] = 'ASSIGNED'
      element << expected_id
      element << expected_assigned_organization
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('custodian')
      element[:typeCode] = 'CST'
      element << expected_assigned_entity
      element
    end

    it 'builds an Ox element with custodian attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_vba_orchestration' do
    subject { described_class.build_vba_orchestration }

    let(:expected_value_element) do
      element = Ox::Element.new('value')
      element[:extension] = 'VBA'
      element[:root] = MPI::Constants::VA_ROOT_OID
      element
    end
    let(:expected_semantics_text_element) do
      element = Ox::Element.new('semanticsText')
      element.replace_text('MVI.ORCHESTRATION')
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('otherIDsScopingOrganization')
      element << expected_value_element
      element << expected_semantics_text_element
      element
    end

    it 'builds an Ox element with vba orchestration attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_control_act_process_element' do
    subject { described_class.build_control_act_process_element }

    let(:expected_element) do
      element = Ox::Element.new('controlActProcess')
      element[:classCode] = 'CACT'
      element[:moodCode] = 'EVN'
      element
    end

    it 'builds an Ox element with control act process attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_code' do
    subject { described_class.build_code(code:) }

    let(:code) { 'some-code' }
    let(:expected_element) do
      element = Ox::Element.new('code')
      element[:code] = code
      element[:codeSystem] = '2.16.840.1.113883.1.6'
      element
    end

    it 'builds an Ox element with code attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_parameter_list_element' do
    subject { described_class.build_parameter_list_element }

    let(:expected_element) do
      Ox::Element.new('parameterList')
    end

    it 'builds an Ox element with parameter list element' do
      expect(subject).to eq(expected_element)
    end
  end
end
