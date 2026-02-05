# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::CreateDailyExcelFiles, form: :education_benefits, type: :model do
  # Changed from application_10282 to application_form to fix Naming/VariableNumber
  let!(:application_form) do
    create(:va10282).education_benefits_claim
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:form_10282_sftp_upload).and_return(true)
  end

  after do
    FileUtils.rm_rf(Dir.glob('tmp/**/*.csv'))
  end

  context 'with the feature flag disabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:form_10282_sftp_upload).and_return(false)
    end

    it 'just returns immediately' do
      expect(SFTPWriter::Factory).not_to receive(:get_writer)
      expect { described_class.new.perform }.not_to change { EducationBenefitsClaim.unprocessed.count }
    end
  end

  context 'scheduling' do
    before do
      allow(Rails.env).to receive('development?').and_return(true)
    end

    context 'job only runs on business days', run_at: '2016-12-31 00:00:00 EDT' do
      let(:scheduler) { Rufus::Scheduler.new }
      let(:possible_runs) do
        {
          '2017-01-02 03:00:00 -0500': false,
          '2017-01-03 03:00:00 -0500': true,
          '2017-01-04 03:00:00 -0500': true,
          '2017-01-05 03:00:00 -0500': true,
          '2017-01-06 03:00:00 -0500': true
        }
      end

      it 'skips observed holidays' do
        possible_runs.each do |day, should_run|
          Timecop.freeze(Time.zone.parse(day.to_s).beginning_of_day) do
            expect(described_class.new.perform).to be(should_run)
          end
        end
      end
    end

    # Fixed RSpec/SubjectStub by using instance instead of subject
    it 'logs a message on holidays', run_at: '2017-01-02 03:00:00 EDT' do
      instance = described_class.new
      allow(instance).to receive(:write_csv_file)
      allow(instance).to receive(:log_info)

      expect(instance.perform).to be false
      expect(instance).to have_received(:log_info).with("CreateDailyExcelFiles: Skipping on a Holiday: New Year's Day")
    end
  end

  describe '#perform' do
    context 'with a mix of valid and invalid records', run_at: '2016-09-16 03:00:00 EDT' do
      before do
        allow(Rails.env).to receive('development?').and_return(true)
        application_form.saved_claim.form = {}.to_json
        application_form.saved_claim.save!(validate: false) # Make this claim malformed
        create(:va10282)
        # clear out old test files
        FileUtils.rm_rf(Dir.glob('tmp/*.csv'))
      end

      it 'processes the valid records' do
        expect { described_class.new.perform }.to change { EducationBenefitsClaim.unprocessed.count }.from(2).to(0)
        expect(Dir['tmp/*.csv'].count).to eq(1)
      end
    end

    context 'with records in staging', run_at: '2016-09-16 03:00:00 EDT' do
      before do
        application_form.saved_claim.form = {}.to_json
        create(:va10282)
        ActionMailer::Base.deliveries.clear
      end

      it 'processes records and uploads to SFTP' do
        with_settings(Settings, hostname: 'staging-api.va.gov') do
          expect(SFTPWriter::Factory).to receive(:get_writer).and_call_original
          expect { described_class.new.perform }.to change { EducationBenefitsClaim.unprocessed.count }.from(2).to(0)
          expect(Dir['tmp/form_10282/*.csv'].count).to eq(1)
        end
      end
    end

    context 'with no records', run_at: '2016-09-16 03:00:00 EDT' do
      before do
        EducationBenefitsClaim.delete_all
      end

      # Fixed RSpec/SubjectStub by using instance instead of subject
      it 'prints a statement and exits' do
        instance = described_class.new
        allow(instance).to receive(:write_csv_file)
        allow(instance).to receive(:log_info)

        expect(instance.perform).to be(true)
        expect(instance).to have_received(:log_info).with('CreateDailyExcelFiles: No records to process.')
      end
    end
  end

  describe '#write_csv_file' do
    let(:filename) { "22-10282_#{Time.zone.now.strftime('%m%d%Y_%H%M%S')}.csv" }
    let(:test_records) do
      [
        double('Record',
               name: 'John Doe',
               first_name: 'John',
               last_name: 'Doe',
               military_affiliation: 'Veteran',
               phone_number: '555-555-5555',
               email_address: 'john@example.com',
               country: 'USA',
               state: 'CA',
               race_ethnicity: 'White',
               gender: 'Male',
               education_level: "Bachelor's",
               employment_status: 'Employed',
               salary: '75000',
               technology_industry: 'Software')
      ]
    end

    before do
      allow(File).to receive(:write)
    end

    it 'creates a CSV file with correct headers and data' do
      instance = described_class.new
      csv_contents = instance.write_csv_file(test_records, filename)
      parsed_csv = CSV.parse(csv_contents)

      expect(parsed_csv.first).to eq(described_class::HEADERS)

      data_row = parsed_csv[1]
      expect(data_row).to eq([
                               'John Doe',
                               'John',
                               'Doe',
                               'Veteran',
                               '555-555-5555',
                               'john@example.com',
                               'USA',
                               'CA',
                               'White',
                               'Male',
                               "Bachelor's",
                               'Employed',
                               '75000',
                               'Software'
                             ])
    end

    it 'writes the CSV contents to a file' do
      instance = described_class.new
      instance.write_csv_file(test_records, filename)
      expect(File).to have_received(:write).with("tmp/#{filename}", anything)
    end

    context 'when a record fails to process' do
      let(:error_record) do
        double('ErrorRecord').tap do |record|
          allow(record).to receive(:name).and_raise(StandardError.new('Test error'))
          # Fixed Style/SlicingWithRange
          described_class::EXCEL_FIELDS[1..].each do |field|
            allow(record).to receive(field).and_return('test')
          end
        end
      end
    end
  end
end
