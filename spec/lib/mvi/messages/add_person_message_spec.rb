require 'rails_helper'
require 'mvi/messages/add_person_message'

describe MVI::Messages::AddPersonMessage do
  describe '.build' do
    context 'with first, last, dob, and ssn from ID.me login and a vets.gov uuid' do
      let(:xml) { subject.build('abc123','John', 'Smith', Time.new(1980, 1, 1), '555-44-3333') }
      let(:parsed_xml) { Ox.parse(xml) }
      let(:patient_path) { 'controlActProcess/subject/registrationEvent/subject1/patient' }
      it 'should have a patient node' do
        puts xml
        expect(
          parsed_xml.locate(patient_path).first
        ).to_not be_nil
      end
    end
  end
end
