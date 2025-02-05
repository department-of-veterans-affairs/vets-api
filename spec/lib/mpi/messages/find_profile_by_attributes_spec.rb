# frozen_string_literal: true

require 'rails_helper'
require 'mpi/messages/find_profile_by_attributes'

describe MPI::Messages::FindProfileByAttributes do
  describe '.perform' do
    subject do
      described_class.new(first_name:,
                          middle_name:,
                          last_name:,
                          birth_date:,
                          ssn:,
                          gender:,
                          orch_search:,
                          edipi:,
                          search_type:).perform
    end

    let(:first_name) { 'some-first-name' }
    let(:middle_name) { 'some-middle-name' }
    let(:last_name) { 'some-last-name' }
    let(:birth_date) { '10-1-2020' }
    let(:gender) { 'some-gender' }
    let(:ssn) { 'some-ssn' }
    let(:orch_search) { 'some-orch_search' }
    let(:edipi) { 'some-edipi' }
    let(:search_type) { 'some-search-type' }

    context 'missing required fields' do
      shared_context 'missing required fields response' do
        let(:expected_error) { MPI::Errors::ArgumentError }
        let(:expected_error_message) { "Required values missing: [:#{missing_value}]" }
        let(:expected_logger_message) do
          "[FindProfileByAttributes] Failed to build request: #{expected_error_message}"
        end

        it 'raises an Argument Error with expected message and logs expected log' do
          expect(Rails.logger).to receive(:error).with(expected_logger_message)
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when first_name is not present' do
        let(:first_name) { [] }
        let(:missing_value) { :first_name }

        it_behaves_like 'missing required fields response'
      end

      context 'when last_name is not present' do
        let(:last_name) { nil }
        let(:missing_value) { :last_name }

        it_behaves_like 'missing required fields response'
      end

      context 'when birth_date is not present' do
        let(:birth_date) { nil }
        let(:missing_value) { :birth_date }

        it_behaves_like 'missing required fields response'
      end

      context 'when ssn is not present' do
        let(:ssn) { nil }
        let(:missing_value) { :ssn }

        it_behaves_like 'missing required fields response'
      end

      context 'when edipi is not present' do
        let(:edipi) { nil }
        let(:missing_value) { :edipi }

        context 'and orch_search is set to true' do
          let(:orch_search) { true }

          it_behaves_like 'missing required fields response'
        end

        context 'and orch_search is set to false' do
          let(:orch_search) { false }

          it 'does not raise an error' do
            expect { subject }.not_to raise_error
          end
        end
      end
    end

    context 'with a valid set of parameters' do
      let(:idm_path) { 'env:Envelope/env:Body/idm:PRPA_IN201305UV02' }
      let(:parameter_list_path) { "#{idm_path}/controlActProcess/queryByParameter/parameterList" }

      context 'when orch_search is set to true' do
        it 'has orchestration related params' do
          expect(subject).to eq_text_at_path(
            "#{parameter_list_path}/otherIDsScopingOrganization/semanticsText",
            'MVI.ORCHESTRATION'
          )
        end
      end

      it 'has a USDSVA extension with a uuid' do
        expect(subject).to match_at_path("#{idm_path}/id/@extension", /200VGOV-\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
      end

      it 'has a sender extension' do
        expect(subject).to eq_at_path("#{idm_path}/sender/device/id/@extension", '200VGOV')
      end

      it 'has a receiver extension' do
        expect(subject).to eq_at_path("#{idm_path}/receiver/device/id/@extension", '200M')
      end

      it 'has a dataEnterer node' do
        expect(subject).to eq_at_path("#{idm_path}/controlActProcess/dataEnterer/@typeCode", 'ENT')
        expect(subject).to eq_at_path("#{idm_path}/controlActProcess/dataEnterer/@contextControlCode", 'AP')
        expect(subject).to eq_text_at_path(
          "#{idm_path}/controlActProcess/dataEnterer/assignedPerson/assignedPerson/name/given[0]", first_name
        )
        expect(subject).to eq_text_at_path(
          "#{idm_path}/controlActProcess/dataEnterer/assignedPerson/assignedPerson/name/given[1]", middle_name
        )
        expect(subject).to eq_text_at_path(
          "#{idm_path}/controlActProcess/dataEnterer/assignedPerson/assignedPerson/name/family", last_name
        )
      end

      it 'has the correct query parameter order' do
        parsed_subject = Ox.parse(subject)
        nodes = parsed_subject.locate(parameter_list_path).first.nodes
        expect(nodes[0].value).to eq('livingSubjectAdministrativeGender')
        expect(nodes[1].value).to eq('livingSubjectBirthTime')
        expect(nodes[2].value).to eq('livingSubjectId')
        expect(nodes[3].value).to eq('livingSubjectName')
      end

      it 'has a name node' do
        expect(subject).to eq_text_at_path("#{parameter_list_path}/livingSubjectName/value/given[0]", first_name)
        expect(subject).to eq_text_at_path("#{parameter_list_path}/livingSubjectName/value/given[1]",
                                           middle_name)
        expect(subject).to eq_text_at_path("#{parameter_list_path}/livingSubjectName/value/family", last_name)
        expect(subject).to eq_text_at_path("#{parameter_list_path}/livingSubjectName/semanticsText", 'Legal Name')
      end

      it 'has a gender node' do
        expect(subject).to eq_at_path("#{parameter_list_path}/livingSubjectAdministrativeGender/value/@code", gender)
        expect(subject).to eq_text_at_path("#{parameter_list_path}/livingSubjectAdministrativeGender/semanticsText",
                                           'Gender')
      end

      it 'has a birth time node' do
        expect(subject).to eq_at_path("#{parameter_list_path}/livingSubjectBirthTime/value/@value",
                                      Date.parse(birth_date)&.strftime('%Y%m%d'))
        expect(subject).to eq_text_at_path("#{parameter_list_path}/livingSubjectBirthTime/semanticsText",
                                           'Date of Birth')
      end

      it 'has a social security number node' do
        expect(subject).to eq_at_path("#{parameter_list_path}/livingSubjectId/value/@extension", ssn)
      end
    end
  end
end
