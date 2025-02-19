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

    it 'saves valid form from S3 file' do
      allow(objects).to receive(:collect).and_return(file_names1)
      allow(Tempfile).to receive(:new).and_return(tempfile1)

      expect(Rails.logger).not_to receive(:error)
      expect(Rails.logger).not_to receive(:warn)

      expect { subject.perform }.to change { Form1095B.count }.from(0).to(1)
    end

    it 'saves multiple forms from a file' do
      allow(objects).to receive(:collect).and_return(file_names2)
      allow(Tempfile).to receive(:new).and_return(tempfile2)

      expect(Rails.logger).not_to receive(:error)
      expect(Rails.logger).not_to receive(:warn)

      expect { subject.perform }.to change { Form1095B.count }.from(0).to(8)
    end

    it 'does not save save data and deletes file when user data is missing icn' do
      allow(objects).to receive(:collect).and_return(file_names3)
      allow(Tempfile).to receive(:new).and_return(tempfile3)

      expect(Rails.logger).not_to receive(:error)
      expect(Rails.logger).not_to receive(:warn)
      expect(bucket).to receive(:delete_objects)

       expect { subject.perform }.not_to change { Form1095B.count }.from(0)
    end

    it 'raises an error and does not delete file when error is encountered processing the file' do
      allow(objects).to receive(:collect).and_return(file_names3)
      allow(subject).to receive(:download_and_process_file?).and_return(false)

      expect(Rails.logger).to receive(:error).at_least(:once).with(
        "failed to save  forms from file: #{file_names3.first}; successfully saved  forms"
      )
      expect(bucket).not_to receive(:delete_objects)

      expect { subject.perform }.not_to change { Form1095B.count }.from(0)
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

        expect {
          subject.perform
        }.to change { [JSON.parse(form1.reload.form_data), JSON.parse(form2.reload.form_data)] }.from(
          [{"first_name"=>"First",
           "middle_name"=>"Middle",
           "last_name"=>"Last",
           "last_4_ssn"=>"1234",
           "address"=>"123 Test st",
           "city"=>"Hollywood",
           "state"=>"CA",
           "zip_code"=>"12345",
           "country"=>"USA",
           "is_beneficiary"=>false,
           "is_corrected"=>false,
           "coverage_months"=>[true, true, true, true, true, true, true, true, true, true, true, true, true]},
          {"first_name"=>"First",
           "middle_name"=>"Middle",
           "last_name"=>"Last",
           "last_4_ssn"=>"1234",
           "address"=>"123 Test st",
           "city"=>"Hollywood",
           "state"=>"CA",
           "zip_code"=>"12345",
           "country"=>"USA",
           "is_beneficiary"=>false,
           "is_corrected"=>false,
           "coverage_months"=>[true, true, true, true, true, true, true, true, true, true, true, true, true]}]
        ).to(
          [{"last_name"=>"Last",
           "first_name"=>"First",
           "middle_name"=>"Middle",
           "last_4_ssn"=>"6788",
           "birth_date"=>"19580317",
           "address"=>"123 Test ST",
           "city"=>"BRANDON",
           "state"=>"FL",
           "country"=>"USA",
           "zip_code"=>"33511-2216",
           "foreign_zip"=>"",
           "province"=>"",
           "coverage_months"=>[false, false, false, false, false, false, false, true, true, true, true, true, true],
           "is_corrected"=>true,
           "is_beneficiary"=>true},
          {"last_name"=>"Lastnamé",
           "first_name"=>"Fïrstnåme",
           "middle_name"=>"",
           "last_4_ssn"=>"6788",
           "birth_date"=>"19580317",
           "address"=>"123 Test ST",
           "city"=>"BRANDON",
           "state"=>"FL",
           "country"=>"USA",
           "zip_code"=>"33511-2216",
           "foreign_zip"=>"",
           "province"=>"",
           "coverage_months"=>[true, false, false, false, false, false, false, false, false, false, false, false, false],
           "is_corrected"=>true,
           "is_beneficiary"=>true}]
        )
      end
    end
  end
end
