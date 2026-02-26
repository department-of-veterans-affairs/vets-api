# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va220989'

describe PdfFill::Forms::Va220989 do
  subject { described_class.new(form_data) }

  let(:form_data) do
    JSON.parse(Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0989', 'minimal.json').read)
  end

  describe '#merge_fields' do
    let(:merged_fields) { subject.merge_fields }

    it 'formats the applicant name correctly' do
      merged_data = subject.merge_fields

      expect(merged_data['applicantName']).to eq('John Doe')
    end

    it 'formats the mailing address correctly' do
      merged_data = subject.merge_fields

      expect(merged_data['mailingAddress']).to eq('111 2nd St S, Seattle, WA, 98101, USA')
    end

    it 'formats the va file number correctly' do
      merged_data = subject.merge_fields

      expect(merged_data['vaFileNumber']).to eq('123456789')
    end

    it 'formats the radio buttons inputs correctly' do
      merged_data = subject.merge_fields

      expect(merged_data['schoolWasClosed']).to eq('YES')
      expect(merged_data['didCompleteProgramOfStudy']).to eq('YES')
      expect(merged_data['didReceiveCredit']).to eq('YES')
      expect(merged_data['wasEnrolledWhenSchoolClosed']).to eq('YES')
      expect(merged_data['wasOnApprovedLeave']).to eq('YES')
      expect(merged_data['withdrewPriorToClosing']).to eq('YES')
      expect(merged_data['enrolledAtNewSchool']).to eq('YES')
      expect(merged_data['isUsingTeachoutAgreement']).to eq('YES')
      expect(merged_data['newSchoolGrants12OrMoreCredits']).to eq('YES')
      expect(merged_data['schoolDidTransferCredits']).to eq('YES')
    end

    it 'formats the old school name and address' do
      merged_data = subject.merge_fields

      expect(merged_data['closedSchoolNameAndAddress']).to eq("Test U\n111 2nd St S\nSeattle, WA, 98101\nUSA\n")
    end

    it 'formats the new school name and program' do
      merged_data = subject.merge_fields

      expect(merged_data['newSchoolAndProgramName']).to eq("New School\nPhysics 2.0\n")
    end

    it 'formats the signature and signed date' do
      merged_data = subject.merge_fields

      expect(merged_data['statementOfTruthSignature']).to eq('John Doe')
      expect(merged_data['dateSigned']).to eq('01,01,2025')
    end
  end

  describe 'filling out pdf' do
    # let(:file_path) { 'tmp/pdfs/10278_test' }

    after do
      FileUtils.rm_rf('tmp/pdfs')
    end

    def get_field_value(fields, name)
      fields.find { |f| f.name == name }&.value
    end

    context 'with a normal set of responses' do
      let(:claim) { create(:va0989) }

      it 'fills in the correct field values' do
        file_path = claim.to_pdf
        fields = PdfForms.new(Settings.binaries.pdftk).get_fields(file_path)

        expect(get_field_value(fields, 'applicant_name')).to eq 'John Doe'
        expect(get_field_value(fields, 'va_file_number')).to eq '123456789'
        expect(get_field_value(fields, 'signature')).to eq 'John Doe'
        expect(get_field_value(fields,
                               'closed_school_name_and_address')).to eq "Test U\r111 2nd St S\rSeattle, WA, 98101\rUSA"
      end
    end

    context 'with a non-closed set of responses' do
      let(:claim) { create(:va0989_not_closed) }

      it 'fills in the correct field values' do
        file_path = claim.to_pdf
        fields = PdfForms.new(Settings.binaries.pdftk).get_fields(file_path)

        expect(get_field_value(fields, 'applicant_name')).to eq 'John Doe'
        expect(get_field_value(fields, 'va_file_number')).to eq '123456789'
        expect(get_field_value(fields, 'signature')).to eq 'John Doe'
        expect(get_field_value(fields, 'closed_school_name_and_address')).to eq ''
        expect(get_field_value(fields, 'remarks')).to eq 'lorem ipsum'
      end
    end
  end
end
