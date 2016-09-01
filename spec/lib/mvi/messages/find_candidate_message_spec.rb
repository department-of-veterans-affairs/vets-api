require 'rails_helper'
require 'mvi/messages/find_candidate_message'

describe MVI::Messages::FindCandidateMessage do
  describe '.build' do
    context 'with first, last, dob, and ssn from ID.me login and a vets.gov uuid' do
      let(:xml) { subject.build('abc123','John', 'Smith', Time.new(1980, 1, 1), '555-44-3333') }
      let(:parsed_xml) { Ox.parse(xml) }
      let(:parameter_list_path) { 'controlActProcess/queryByParameter/parameterList' }
      it 'should have a USDVA extension' do
        expect(
          parsed_xml.locate('id/@extension').first
        ).to eq('abc123^PN^200VETS^USDVA')
      end
      it 'should have a name node' do
        expect(
          parsed_xml.locate("#{parameter_list_path}/livingSubjectName/value/given").first.text
        ).to eq("John")
        expect(
          parsed_xml.locate("#{parameter_list_path}/livingSubjectName/value/family").first.text
        ).to eq("Smith")
      end
      it 'should have a birth time (dob) node' do
        expect(
          parsed_xml.locate("#{parameter_list_path}/livingSubjectBirthTime/value/@value").first
        ).to eq('19800101')
      end
    end
  end
end
