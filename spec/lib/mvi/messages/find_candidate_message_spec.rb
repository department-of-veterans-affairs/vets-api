require 'rails_helper'
require 'mvi/messages/find_candidate_message'

describe MVI::Messages::FindCandidateMessage do
  describe '.build' do
    context 'with first, last, dob, and ssn from auth provider' do

      let(:xml) { MVI::Messages::FindCandidateMessage.build('John', 'Smith', Time.new(1980, 1, 1), '555-44-3333') }
      let(:idm_path) { 'env:Body/idm:PRPA_IN201305UV02' }
      let(:parameter_list_path) { "#{idm_path}/controlActProcess/queryByParameter/parameterList" }

      it 'should have a USDSVA extension with a uuid' do
        puts xml
        expect(xml).to match_at_path("#{idm_path}/id/@extension", /200VGOV-\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
      end

      it 'should have a sender extension' do
        expect(xml).to eq_at_path("#{idm_path}/sender/device/id/@extension", '200VGOV')
      end

      it 'should have a receiver extension' do
        expect(xml).to eq_at_path("#{idm_path}/receiver/device/id/@extension", '200M')
      end

      it 'should have a name node' do
        expect(xml).to eq_text_at_path("#{parameter_list_path}/livingSubjectName/value/given", 'John')
        expect(xml).to eq_text_at_path("#{parameter_list_path}/livingSubjectName/value/family", 'Smith')
      end

      it 'should have a birth time (dob) node' do
        expect(xml).to eq_at_path("#{parameter_list_path}/livingSubjectBirthTime/value/@value", '19800101')
      end

      it 'should have a social security number (ssn) node' do
        expect(xml).to eq_at_path("#{parameter_list_path}/livingSubjectId/value/@extention", '555-44-3333')
      end
    end
    context 'a missing argument' do
      it 'should throw an argument error' do
        expect do
          MVI::Messages::FindCandidateMessage.build('John', 'Smith', Time.new(1980, 1, 1))
        end.to raise_error(ArgumentError, 'wrong number of arguments (given 3, expected 4)')
      end
    end
    context 'with an invalid date' do
      it 'should throw an argument error' do
        expect do
          MVI::Messages::FindCandidateMessage.build('John', 'Smith', '19800101', '555-44-3333')
        end.to raise_error(ArgumentError, 'dob should be a Time object')
      end
    end
    context 'with invalid name args' do
      it 'should throw an argument error' do
        expect do
          MVI::Messages::FindCandidateMessage.build(:John, 5, Time.new(1980, 1, 1), '555-44-3333')
        end.to raise_error(ArgumentError, 'first and last name sould be Strings')
      end
    end
    context 'with an invalid ssn' do
      it 'should throw an argument error' do
        expect do
          MVI::Messages::FindCandidateMessage.build('John', 'Smith', Time.new(1980, 1, 1), '555-4-3333')
        end.to raise_error(ArgumentError, 'ssn should be of format \d{3}-\d{2}-\d{4}')
      end
    end
  end
end
