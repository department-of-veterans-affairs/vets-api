# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::DependencyClaim do
  subject { create(:dependency_claim) }

  let(:all_flows_payload) { FactoryBot.build(:form_686c_674_kitchen_sink) }
  let(:adopted_child) { FactoryBot.build(:adopted_child_lives_with_veteran) }
  let(:form_674_only) { FactoryBot.build(:form_674_only) }
  let(:doc_type) { '148' }
  let(:va_file_number) { subject.parsed_form['veteran_information']['va_file_number'] }
  let(:va_file_number_with_payload) do
    {
      'veteran_information' => {
        'birth_date' => '1809-02-12',
        'full_name' => {
          'first' => 'WESLEY', 'last' => 'FORD', 'middle' => nil
        },
        'ssn' => va_file_number,
        'va_file_number' => va_file_number
      }
    }
  end

  let(:file_path) { "tmp/pdfs/686C-674_#{subject.id}_final.pdf" }

  describe '#format_and_uplad_pdf' do
    it 'uploads to vbms' do
      uploader = double(ClaimsApi::VBMSUploader)
      expect(ClaimsApi::VBMSUploader).to receive(:new).with(
        filepath: file_path,
        file_number: va_file_number,
        doc_type:
      ).and_return(uploader)
      expect(uploader).to receive(:upload!)

      subject.upload_pdf('686C-674')
    end
  end

  context 'both forms' do
    subject { described_class.new(form: all_flows_payload.to_json) }

    describe '#formatted_686_data' do
      it 'returns all data for 686 submissions' do
        formatted_data = subject.formatted_686_data(va_file_number_with_payload)
        expect(formatted_data).to include(:veteran_information)
      end
    end

    describe '#formatted_674_data' do
      it 'returns all data for 674 submissions' do
        formatted_data = subject.formatted_674_data(va_file_number_with_payload)
        expect(formatted_data).to include(:dependents_application)
        expect(formatted_data[:dependents_application]).to include(:student_name_and_ssn)
      end
    end

    describe '#submittable_686?' do
      it 'checks if there are 686 flows to process' do
        expect(subject.submittable_686?).to eq(true)
      end
    end

    describe '#submittable_674?' do
      it 'checks if there are 674 to process' do
        expect(subject.submittable_674?).to eq(true)
      end
    end
  end

  context '674 form only' do
    subject { described_class.new(form: form_674_only.to_json) }

    describe '#submittable_686?' do
      it 'returns false if there is no 686 to process' do
        expect(subject.submittable_686?).to eq(false)
      end
    end
  end

  context 'with adopted child' do
    subject { described_class.new(form: adopted_child.to_json) }

    describe '#submittable_674?' do
      it 'returns false if there is no 674 to process' do
        expect(subject.submittable_674?).to eq(false)
      end
    end

    describe '#regional_office' do
      it 'expects to be empty always' do
        expect(subject.regional_office).to eq([])
      end
    end
  end
end
