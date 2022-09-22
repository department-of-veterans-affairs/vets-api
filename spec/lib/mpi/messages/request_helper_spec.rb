# frozen_string_literal: true

require 'rails_helper'
require 'mpi/messages/request_helper'

describe MPI::Messages::RequestHelper do
  describe '.build_identifier' do
    subject { described_class.build_identifier(identifier: identifier) }

    let(:identifier) { 'some-identifier' }
    let(:expected_element) do
      element = Ox::Element.new('id')
      element[:root] = '2.16.840.1.113883.4.349'
      element[:extension] = identifier
      element
    end

    it 'builds an Ox element with identifier attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_edipi_identifier' do
    subject { described_class.build_edipi_identifier(edipi: edipi) }

    let(:edipi) { 'some-edipi' }
    let(:expected_element) do
      element = Ox::Element.new('id')
      element[:root] = '2.16.840.1.113883.3.42.10001.100001.12'
      element[:extension] = edipi
      element
    end

    it 'builds an Ox element with edipi attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_name' do
    subject { described_class.build_name(given_names: given_names, family_name: family_name) }

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
    subject { described_class.build_birth_date(birth_date: birth_date) }

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
    subject { described_class.build_ssn(ssn: ssn) }

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
    subject { described_class.build_gender(gender: gender) }

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

  describe '.build_orchestrated_search' do
    subject { described_class.build_orchestrated_search(edipi: edipi) }

    before { Timecop.freeze }

    after { Timecop.return }

    let(:edipi) { 'some-edipi' }
    let(:expected_id_element) do
      element = Ox::Element.new('id')
      element[:root] = '2.16.840.1.113883.4.349'
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
    subject { described_class.build_query_by_parameter(search_type: search_type) }

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
    let(:expected_element) do
      element = Ox::Element.new('queryByParameter')
      element << expected_query_id_element
      element << expected_status_code_element
      element << expected_modify_code_element
      element << expected_initial_quantity_element
      element
    end

    it 'builds an Ox element with query by parameter attribute' do
      expect(subject).to eq(expected_element)
    end
  end

  describe '.build_assigned_person_instance' do
    subject { described_class.build_assigned_person_instance(given_names: given_names, family_name: family_name) }

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
    subject { described_class.build_assigned_person_ssn(ssn: ssn) }

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

  describe '.build_vba_orchestration' do
    subject { described_class.build_vba_orchestration }

    let(:expected_value_element) do
      element = Ox::Element.new('value')
      element[:extension] = 'VBA'
      element[:root] = '2.16.840.1.113883.4.349'
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

  describe '.build_control_act_process' do
    subject { described_class.build_control_act_process }

    let(:expected_control_act_process_element) do
      element = Ox::Element.new('code')
      element[:code] = 'PRPA_TE201305UV02'
      element[:codeSystem] = '2.16.840.1.113883.1.6'
      element
    end
    let(:expected_element) do
      element = Ox::Element.new('controlActProcess')
      element[:classCode] = 'CACT'
      element[:moodCode] = 'EVN'
      element << expected_control_act_process_element
      element
    end

    it 'builds an Ox element with control act process attribute' do
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
