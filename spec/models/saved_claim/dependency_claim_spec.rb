# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::DependencyClaim do
  subject { create(:dependency_claim) }

  let(:subject_v2) { create(:dependency_claim_v2) }

  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }
  let(:adopted_child) { build(:adopted_child_lives_with_veteran) }
  let(:adopted_child_v2) { build(:adopted_child_lives_with_veteran_v2) }
  let(:form_674_only) { build(:form_674_only) }
  let(:form_674_only_v2) { build(:form_674_only_v2) }
  let(:doc_type) { '148' }
  let(:va_file_number) { subject.parsed_form['veteran_information']['va_file_number'] }
  let(:va_file_number_v2) { subject_v2.parsed_form['veteran_information']['va_file_number'] }
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
  let(:va_file_number_with_payload_v2) do
    {
      'veteran_information' => {
        'birth_date' => '1809-02-12',
        'full_name' => {
          'first' => 'WESLEY', 'last' => 'FORD', 'middle' => nil
        },
        'ssn' => va_file_number_v2,
        'va_file_number' => va_file_number_v2
      }
    }
  end

  let(:file_path) { "tmp/pdfs/686C-674_#{subject.id}_final.pdf" }
  let(:file_path_v2) { "tmp/pdfs/686C-674-V2_#{subject_v2.id}_final.pdf" }

  describe '#upload_pdf' do
    context 'when :va_dependents_v2 is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(false)
      end

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

    context 'uploader v2' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
      end

      it 'when :va_dependents_v2 is enabled' do
        uploader = double(ClaimsApi::VBMSUploader)
        expect(ClaimsApi::VBMSUploader).to receive(:new).with(
          filepath: file_path_v2,
          file_number: va_file_number_v2,
          doc_type:
        ).and_return(uploader)
        expect(uploader).to receive(:upload!)

        subject_v2.upload_pdf('686C-674-V2')
      end

      it 'when :va_dependents_v2 is enabled upload 674' do
        uploader = double(ClaimsApi::VBMSUploader)
        expect(ClaimsApi::VBMSUploader).to receive(:new).with(
          filepath: "tmp/pdfs/21-674-V2_#{subject_v2.id}_0_final.pdf",
          file_number: va_file_number_v2,
          doc_type:
        ).and_return(uploader)
        expect(uploader).to receive(:upload!)

        subject_v2.upload_pdf('21-674-V2')
      end
    end
  end

  describe 'both forms' do
    context 'va_dependents_v2 is disabled' do
      subject { described_class.new(form: all_flows_payload.to_json) }

      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(false)
      end

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
          expect(subject.submittable_686?).to be(true)
        end
      end

      describe '#submittable_674?' do
        it 'checks if there are 674 to process' do
          expect(subject.submittable_674?).to be(true)
        end
      end
    end

    context 'va_dependents_v2 is enabled' do
      subject { described_class.new(form: all_flows_payload_v2.to_json, use_v2: true) }

      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
      end

      describe '#formatted_686_data' do
        it 'returns all data for 686 submissions' do
          formatted_data = subject.formatted_686_data(va_file_number_with_payload_v2)
          expect(formatted_data).to include(:veteran_information)
        end
      end

      describe '#formatted_674_data' do
        it 'returns all data for 674 submissions' do
          formatted_data = subject.formatted_674_data(va_file_number_with_payload_v2)
          expect(formatted_data).to include(:dependents_application)
          expect(formatted_data[:dependents_application]).to include(:student_information)
        end
      end

      describe '#submittable_686?' do
        it 'checks if there are 686 flows to process' do
          expect(subject.submittable_686?).to be(true)
        end
      end

      describe '#submittable_674?' do
        it 'checks if there are 674 to process' do
          expect(subject.submittable_674?).to be(true)
        end
      end
    end
  end

  describe '674 form only' do
    context 'va_dependents_v2 is disabled' do
      subject { described_class.new(form: form_674_only.to_json) }

      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(false)
      end

      describe '#submittable_686?' do
        it 'returns false if there is no 686 to process' do
          expect(subject.submittable_686?).to be(false)
        end
      end
    end

    context 'va_dependents_v2 is enabled' do
      subject { described_class.new(form: form_674_only_v2.to_json, use_v2: true) }

      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
      end

      describe '#submittable_686?' do
        it 'returns false if there is no 686 to process' do
          expect(subject.submittable_686?).to be(false)
        end
      end
    end
  end

  describe 'with adopted child' do
    context 'va_dependents_v2 is disabled' do
      subject { described_class.new(form: adopted_child.to_json) }

      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(false)
      end

      describe '#submittable_674?' do
        it 'returns false if there is no 674 to process' do
          expect(subject.submittable_674?).to be(false)
        end
      end

      describe '#regional_office' do
        it 'expects to be empty always' do
          expect(subject.regional_office).to eq([])
        end
      end
    end

    context 'va_dependents_v2 is enabled' do
      subject { described_class.new(form: adopted_child_v2.to_json, use_v2: true) }

      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
      end

      describe '#submittable_674?' do
        it 'returns false if there is no 674 to process' do
          expect(subject.submittable_674?).to be(false)
        end
      end

      describe '#regional_office' do
        it 'expects to be empty always' do
          expect(subject.regional_office).to eq([])
        end
      end
    end
  end

  context 'v2 form' do
    subject { described_class.new(form: all_flows_payload_v2.to_json, use_v2: true) }

    before do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
    end

    it 'has a form id of 686C-674-V2' do
      expect(subject.form_id).to eq('686C-674-V2')
    end
  end
end
