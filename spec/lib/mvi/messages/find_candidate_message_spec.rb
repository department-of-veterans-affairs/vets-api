require 'rails_helper'
require 'mvi/messages/find_candidate_message'
require 'rspec/matchers'
require 'equivalent-xml'

describe MVI::Messages::FindCandidateMessage do
  describe '.build' do
    context 'with first, last, dob, and ssn from ID.me login and a vets.gov uuid' do
      let(:xml) { subject.build('abc123','John', 'Smith', Time.new(1980, 1, 1), '555-44-3333') }
      let(:parsed_xml) { Ox.parse(xml) }
      let(:idm_path) { 'env:Body/idm:PRPA_IN201305UV02' }
      let(:parameter_list_path) { "#{idm_path}/controlActProcess/queryByParameter/parameterList" }

      it 'should have a USDSVA extension with a uuid' do
        expect(
          parsed_xml.locate("#{idm_path}/id/@extension").first
        ).to match(/200VGOV-\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
      end
      it 'should have a name node' do
        expect(
          parsed_xml.locate("#{parameter_list_path}/livingSubjectName/value/given").first.text
        ).to eq('John')
        expect(
          parsed_xml.locate("#{parameter_list_path}/livingSubjectName/value/family").first.text
        ).to eq('Smith')
      end
      it 'should have a birth time (dob) node' do
        expect(
          parsed_xml.locate("#{parameter_list_path}/livingSubjectBirthTime/value/@value").first
        ).to eq('19800101')
      end
      it 'should have a social security number (ssn) node' do
        expect(
          parsed_xml.locate("#{parameter_list_path}/livingSubjectId/value/@extention").first
        ).to eq('555-44-3333')
      end
    end
  end
end
