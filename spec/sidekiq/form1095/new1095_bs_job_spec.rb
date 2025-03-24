# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1095::New1095BsJob, type: :job do
  describe 'perform' do
    let(:bucket) { double }
    let(:s3_resource) { double }
    let(:objects) { double }
    let(:object) { double }
    let(:file_names1) { %w[MEC_DataExtract_O_2021_V_2021123016452.txt] }
    let(:file_data1) { File.read('spec/support/form1095/single_valid_form.txt') }
    let(:tempfile1) do
      tf = Tempfile.new(file_names1[0])
      tf.write(file_data1)
      tf.rewind
      tf
    end

    let(:file_names2) { %w[MEC_DataExtract_O_2020_B_2020123017382.txt] }
    let(:file_data2) { File.read('spec/support/form1095/multiple_valid_forms.txt') }
    let(:tempfile2) do
      tf = Tempfile.new(file_names2[0])
      tf.write(file_data2)
      tf.rewind
      tf
    end

    let(:file_names3) { %w[MEC_DataExtract_O_2021_V_2021123014353.txt] }
    let(:file_data3) { File.read('spec/support/form1095/single_invalid_form.txt') }
    let(:tempfile3) do
      tf = Tempfile.new(file_names3[0])
      tf.write(file_data3)
      tf.rewind
      tf
    end

    let(:file_names4) { %w[MEC_DataExtract_C_2020_B_2021012117364.txt] }
    let(:file_data4) { File.read('spec/support/form1095/multiple_valid_forms_corrections.txt') }
    let(:tempfile4) do
      tf = Tempfile.new(file_names4[0])
      tf.write(file_data4)
      tf.rewind
      tf
    end

    before do
      allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)
      allow(s3_resource).to receive(:bucket).and_return(bucket)
      allow(bucket).to receive_messages(objects:, delete_objects: true, object:)
      allow(object).to receive(:get).and_return(nil)
    end

    context 'when file is for a past tax year' do
      it 'does not save data and deletes the file' do
        allow(objects).to receive(:collect).and_return(file_names1)
        allow(Tempfile).to receive(:new).and_return(tempfile1)

        expect(Rails.logger).not_to receive(:error)
        expect(Rails.logger).not_to receive(:warn)
        expect(bucket).to receive(:delete_objects)

        expect { subject.perform }.not_to change(Form1095B, :count).from(0)
      end
    end

    context 'when file is for the current tax year or later' do
      before do
        time = Time.utc(2021, 9, 21, 0, 0, 0)
        Timecop.freeze(time)
      end

      after { Timecop.return }

      it 'saves valid form from S3 file' do
        allow(objects).to receive(:collect).and_return(file_names1)
        allow(Tempfile).to receive(:new).and_return(tempfile1)

        expect(Rails.logger).not_to receive(:error)
        expect(Rails.logger).not_to receive(:warn)

        expect { subject.perform }.to change(Form1095B, :count).from(0).to(1)
      end

      it 'saves multiple forms from a file' do
        allow(objects).to receive(:collect).and_return(file_names2)
        allow(Tempfile).to receive(:new).and_return(tempfile2)

        expect(Rails.logger).not_to receive(:error)
        expect(Rails.logger).not_to receive(:warn)

        expect { subject.perform }.to change(Form1095B, :count).from(0).to(8)
      end

      context 'when user data is missing icn' do
        it 'does not log errors or save form but does deletes file' do
          allow(objects).to receive(:collect).and_return(file_names3)
          allow(Tempfile).to receive(:new).and_return(tempfile3)

          expect(Rails.logger).not_to receive(:error)
          expect(Rails.logger).not_to receive(:warn)
          expect(bucket).to receive(:delete_objects)

          expect { subject.perform }.not_to change(Form1095B, :count).from(0)
        end
      end

      context 'when error is encountered processing the file' do
        it 'raises an error and does not delete file' do
          allow(objects).to receive(:collect).and_return(file_names3)
          allow(Tempfile).to receive(:new).and_return(tempfile3)
          allow(tempfile3).to receive(:each_line).and_raise(RuntimeError, 'Bad file')

          expect(Rails.logger).to receive(:error).once.with('Form1095B Creation Job Error: Error processing file: ' \
                                                            "#{file_names3.first}, on line 0; Bad file")
          expect(Rails.logger).to receive(:error).once.with(
            "Form1095B Creation Job Error: failed to save 0 forms from file: #{file_names3.first}; " \
            'successfully saved 0 forms'
          )
          expect(bucket).not_to receive(:delete_objects)

          expect { subject.perform }.not_to change(Form1095B, :count).from(0)
        end
      end

      context 'saves form corrections from a corrected file' do
        let!(:form1) { create(:form1095_b, tax_year: 2020, veteran_icn: '23456789098765437') }
        let!(:form2) { create(:form1095_b, tax_year: 2020, veteran_icn: '23456789098765464') }

        before do
          allow(objects).to receive(:collect).and_return(file_names4)
          allow(Tempfile).to receive(:new).and_return(tempfile4)
        end

        it 'updates forms without errors' do
          expect(Rails.logger).not_to receive(:error)
          expect(Rails.logger).not_to receive(:warn)

          expect do
            subject.perform
          end.to change { [form1.reload.form_data, form2.reload.form_data] }
        end
      end
    end
  end
end
