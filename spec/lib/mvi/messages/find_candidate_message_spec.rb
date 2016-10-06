# frozen_string_literal: true
require 'rails_helper'
require 'mvi/messages/find_candidate_message'

describe MVI::Messages::FindCandidateMessage do
  describe '.to_xml' do
    context 'with first, last, birth_date, and ssn from auth provider' do
      let(:xml) do
        MVI::Messages::FindCandidateMessage.new(
          %w(John William), 'Smith', Time.new(1980, 1, 1).utc, '555-44-3333', 'M'
        ).to_xml
      end
      let(:idm_path) { 'env:Body/idm:PRPA_IN201305UV02' }
      let(:parameter_list_path) { "#{idm_path}/controlActProcess/queryByParameter/parameterList" }

      it 'should have a USDSVA extension with a uuid' do
        expect(xml).to match_at_path("#{idm_path}/id/@extension", /200VGOV-\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
      end

      it 'should have a sender extension' do
        expect(xml).to eq_at_path("#{idm_path}/sender/device/id/@extension", '200VGOV')
      end

      it 'should have a receiver extension' do
        expect(xml).to eq_at_path("#{idm_path}/receiver/device/id/@extension", '200M')
      end

      it 'should have a name node' do
        expect(xml).to eq_text_at_path("#{parameter_list_path}/livingSubjectName/value/given[0]", 'John')
        expect(xml).to eq_text_at_path("#{parameter_list_path}/livingSubjectName/value/given[1]", 'William')
        expect(xml).to eq_text_at_path("#{parameter_list_path}/livingSubjectName/value/family", 'Smith')
      end

      it 'should have a birth time node' do
        expect(xml).to eq_at_path("#{parameter_list_path}/livingSubjectBirthTime/value/@value", '19800101')
      end

      it 'should have a social security number node' do
        expect(xml).to eq_at_path("#{parameter_list_path}/livingSubjectId/value/@extention", '555-44-3333')
      end

      it 'should have a gender node' do
        expect(xml).to eq_at_path("#{parameter_list_path}/livingSubjectAdministrativeGender/value/@code", 'M')
      end
    end

    context 'missing arguments' do
      it 'should throw an argument error' do
        expect do
          MVI::Messages::FindCandidateMessage.new(%w(John William), 'Smith', Time.new(1980, 1, 1).utc)
        end.to raise_error(ArgumentError, 'wrong number of arguments (given 3, expected 4..5)')
      end
    end
  end
end
