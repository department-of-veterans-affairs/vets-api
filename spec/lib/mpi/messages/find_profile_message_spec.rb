# frozen_string_literal: true

require 'rails_helper'
require 'mpi/messages/find_profile_message'

describe MPI::Messages::FindProfileMessage do
  describe '.to_xml' do
    context 'with first, last, birth_date, and ssn from auth provider' do
      let(:xml) do
        described_class.new(
          given_names: %w[John William],
          last_name: 'Smith',
          birth_date: '1980-1-1',
          ssn: '555-44-3333',
          gender: 'M'
        ).to_xml
      end
      let(:idm_path) { 'env:Body/idm:PRPA_IN201305UV02' }
      let(:parameter_list_path) { "#{idm_path}/controlActProcess/queryByParameter/parameterList" }

      it 'has a USDSVA extension with a uuid' do
        expect(xml).to match_at_path("#{idm_path}/id/@extension", /200VGOV-\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
      end

      it 'has a sender extension' do
        expect(xml).to eq_at_path("#{idm_path}/sender/device/id/@extension", '200VGOV')
      end

      it 'has a receiver extension' do
        expect(xml).to eq_at_path("#{idm_path}/receiver/device/id/@extension", '200M')
      end

      it 'has a dataEnterer node' do
        expect(xml).to eq_at_path("#{idm_path}/controlActProcess/dataEnterer/@typeCode", 'ENT')
        expect(xml).to eq_at_path("#{idm_path}/controlActProcess/dataEnterer/@contextControlCode", 'AP')
        expect(xml).to eq_text_at_path(
          "#{idm_path}/controlActProcess/dataEnterer/assignedPerson/assignedPerson/name/given[0]", 'John'
        )
        expect(xml).to eq_text_at_path(
          "#{idm_path}/controlActProcess/dataEnterer/assignedPerson/assignedPerson/name/given[1]", 'William'
        )
        expect(xml).to eq_text_at_path(
          "#{idm_path}/controlActProcess/dataEnterer/assignedPerson/assignedPerson/name/family", 'Smith'
        )
      end

      it 'has the correct query parameter order' do
        parsed_xml = Ox.parse(xml)
        nodes = parsed_xml.locate(parameter_list_path).first.nodes
        expect(nodes[0].value).to eq('livingSubjectAdministrativeGender')
        expect(nodes[1].value).to eq('livingSubjectBirthTime')
        expect(nodes[2].value).to eq('livingSubjectId')
        expect(nodes[3].value).to eq('livingSubjectName')
      end

      it 'has a name node' do
        expect(xml).to eq_text_at_path("#{parameter_list_path}/livingSubjectName/value/given[0]", 'John')
        expect(xml).to eq_text_at_path("#{parameter_list_path}/livingSubjectName/value/given[1]", 'William')
        expect(xml).to eq_text_at_path("#{parameter_list_path}/livingSubjectName/value/family", 'Smith')
        expect(xml).to eq_text_at_path("#{parameter_list_path}/livingSubjectName/semanticsText", 'Legal Name')
      end

      it 'has a birth time node' do
        expect(xml).to eq_at_path("#{parameter_list_path}/livingSubjectBirthTime/value/@value", '19800101')
        expect(xml).to eq_text_at_path("#{parameter_list_path}/livingSubjectBirthTime/semanticsText", 'Date of Birth')
      end

      it 'has a social security number node' do
        expect(xml).to eq_at_path("#{parameter_list_path}/livingSubjectId/value/@extension", '555-44-3333')
      end

      it 'has a gender node' do
        expect(xml).to eq_at_path("#{parameter_list_path}/livingSubjectAdministrativeGender/value/@code", 'M')
        expect(xml).to eq_text_at_path(
          "#{parameter_list_path}/livingSubjectAdministrativeGender/semanticsText",
          'Gender'
        )
      end

      context 'orchestration' do
        it 'has orchestration related params when enabled' do
          allow(Settings.mvi).to receive(:vba_orchestration).and_return(true)
          expect(xml).to eq_text_at_path(
            "#{parameter_list_path}/otherIDsScopingOrganization/semanticsText",
            'MVI.ORCHESTRATION'
          )
        end
      end
    end

    context 'with nil gender' do
      let(:xml) do
        MPI::Messages::FindProfileMessage.new(
          given_names: %w[John William],
          last_name: 'Smith',
          birth_date: '1980-1-1',
          ssn: '555-44-3333',
          gender: nil
        ).to_xml
      end
      let(:idm_path) { 'env:Body/idm:PRPA_IN201305UV02' }
      let(:parameter_list_path) { "#{idm_path}/controlActProcess/queryByParameter/parameterList" }

      it 'does not have a gender node' do
        expect(xml).to eq_at_path("#{parameter_list_path}/livingSubjectAdministrativeGender/value/@code", nil)
      end

      it 'has the correct query parameter order' do
        parsed_xml = Ox.parse(xml)
        nodes = parsed_xml.locate(parameter_list_path).first.nodes
        expect(nodes[0].value).to eq('livingSubjectBirthTime')
        expect(nodes[1].value).to eq('livingSubjectId')
        expect(nodes[2].value).to eq('livingSubjectName')
      end
    end

    context 'missing arguments' do
      it 'throws an argument error for missing key' do
        expect do
          MPI::Messages::FindProfileMessage.new(
            given_names: %w[John William],
            last_name: 'Smith',
            birth_date: Time.new(1980, 1, 1).utc
          )
        end.to raise_error(ArgumentError, 'required keys are missing: [:ssn]')
      end

      it 'throws an argument error for empty value' do
        expect do
          MPI::Messages::FindProfileMessage.new(
            given_names: %w[John William],
            last_name: '',
            birth_date: Time.new(1980, 1, 1).utc,
            ssn: rand.to_s[2..11]
          )
        end.to raise_error(ArgumentError, 'required values are missing for keys: [:last_name]')
      end

      it 'throws an argument error for nil value' do
        expect do
          MPI::Messages::FindProfileMessage.new(
            given_names: %w[John William],
            last_name: nil,
            birth_date: Time.new(1980, 1, 1).utc,
            ssn: rand.to_s[2..11]
          )
        end.to raise_error(ArgumentError, 'required values are missing for keys: [:last_name]')
      end
    end
  end

  describe '#required_fields_present?' do
    subject { described_class.new(profile) }

    let(:missing_keys) { ':given_names, :last_name, :birth_date, :ssn' }

    context 'missing keys' do
      let(:profile) { {} }

      it 'raises with list of missing keys' do
        expect { subject }.to raise_error(/#{missing_keys}/)
      end
    end

    context 'missing values' do
      let(:profile) { { given_names: nil, last_name: '', birth_date: nil, ssn: '' } }

      it 'raises with list of keys for missing values' do
        expect { subject }.to raise_error(/#{missing_keys}/)
      end
    end
  end
end
