# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::CreateDailySpoolFiles, type: :model, form: :education_benefits do
  subject { described_class.new }

  let!(:application_1606) do
    FactoryGirl.create(:education_benefits_claim)
  end
  let(:line_break) { EducationForm::WINDOWS_NOTEPAD_LINEBREAK }

  context 'scheduling' do
    context 'job only runs on business days', run_at: '2016-12-31 00:00:00 EDT' do
      let(:scheduler) { Rufus::Scheduler.new }
      let(:possible_runs) do
        { '2017-01-02 03:00:00 -0500': false,
          '2017-01-03 03:00:00 -0500': true,
          '2017-01-04 03:00:00 -0500': true,
          '2017-01-05 03:00:00 -0500': true,
          '2017-01-06 03:00:00 -0500': true }
      end

      before do
        yaml = YAML.load_file(File.join(Rails.root, 'config', 'sidekiq_scheduler.yml'))
        cron = yaml['CreateDailySpoolFiles']['cron']
        scheduler.schedule_cron(cron) {} # schedule_cron requires a block
      end

      it 'is only triggered by sidekiq-scheduler on weekdays' do
        upcoming_runs = scheduler.timeline(Time.zone.now, 1.week.from_now).map(&:first)
        expected_runs = possible_runs.keys.map { |d| Time.zone.parse(d.to_s) }
        expect(upcoming_runs).to eq(expected_runs)
      end

      it 'should skip observed holidays' do
        possible_runs.each do |day, should_run|
          Timecop.freeze(Time.zone.parse(day.to_s).beginning_of_day) do
            expect(subject.perform).to be(should_run)
          end
        end
      end
    end

    it 'should log a message on holidays', run_at: '2017-01-02 03:00:00 EDT' do
      expect(subject).not_to receive(:create_files)
      expect(subject.logger).to receive(:info).with("Skipping on a Holiday: New Year's Day")
      expect(subject.perform).to be false
    end

    it 'should not skip informal holidays', run_at: '2017-04-01 03:00:00 EDT' do
      # Sanity check that this *is* an informal holiday we're testing
      expect(Holidays.on(Time.zone.today, :us, :informal).first[:name]).to eq("April Fool's Day")
      expect(subject).to receive(:create_files)
      expect(subject.perform).to be true
    end
  end

  context '#format_application' do
    it 'logs an error if the record is invalid' do
      expect(application_1606).to receive(:open_struct_form).once.and_return(OpenStruct.new)
      expect { subject.format_application(application_1606) }.to raise_error(EducationForm::FormattingError) do |error|
        expect(error.cause.message).to match(/NilClass/)
      end
    end

    it 'tracks and returns a form object' do
      expect(subject).to receive(:track_form_type).with('22-1990', 999)
      result = subject.format_application(application_1606, rpo: 999)
      expect(result).to be_a(EducationForm::Forms::VA1990)
    end

    context 'result tests' do
      subject { described_class.new.format_application(application_1606).text }

      it 'outputs a valid spool file fragment' do
        expect(subject.lines.select { |line| line.length > 80 }).to be_empty
      end

      it 'contains only windows-style newlines' do
        expect(subject).to_not match(/([^\r]\n)/)
      end
    end
  end

  context '#group_submissions_by_region' do
    it 'takes a list of records into chunked forms' do
      base_address = { street: 'A', city: 'B', country: 'USA' }
      # rubocop:disable LineLength
      eastern = EducationBenefitsClaim.create(form: { privacyAgreementAccepted: true, school: { address: base_address.merge(state: 'MD') } }.to_json)
      southern = EducationBenefitsClaim.create(form: { privacyAgreementAccepted: true, school: { address: base_address.merge(state: 'GA') } }.to_json)
      central = EducationBenefitsClaim.create(form: { privacyAgreementAccepted: true, veteranAddress: base_address.merge(state: 'WI') }.to_json)
      eastern_default = EducationBenefitsClaim.create(form: { privacyAgreementAccepted: true }.to_json)
      western = EducationBenefitsClaim.create(form: { privacyAgreementAccepted: true, veteranAddress: base_address.merge(state: 'OK') }.to_json)
      western_phl = EducationBenefitsClaim.create(form: { privacyAgreementAccepted: true, veteranAddress: base_address.merge(state: 'XX', country: 'PHL') }.to_json)
      # rubocop:enable LineLength

      output = subject.group_submissions_by_region([eastern, central, southern, eastern_default, western, western_phl])
      expect(output[:eastern].length).to be(2)
      expect(output[:western].length).to be(3)
      expect(output[:central].length).to be(1)
    end
  end

  context 'create_files', run_at: '2016-09-16 03:00:00 EDT' do
    let(:filename) { '307_09162016_vetsgov.spl' }
    let!(:second_record) { FactoryGirl.create(:education_benefits_claim) }

    context 'in the development env' do
      let(:file_path) { "tmp/spool_files/#{filename}" }

      before do
        expect(Rails.env).to receive('development?').once { true }
      end

      it 'writes a file to the tmp dir' do
        expect(EducationBenefitsClaim.unprocessed).not_to be_empty
        subject.perform
        contents = File.read(file_path)
        expect(contents).to include('APPLICATION FOR VA EDUCATION BENEFITS')
        # Concatenation is done in #write_files, so check for it here in the caller
        expect(contents).to include("*END*#{line_break}*INIT*")
        expect(contents).to include(second_record.confirmation_number)
        expect(contents).to include(application_1606.confirmation_number)
        expect(EducationBenefitsClaim.unprocessed).to be_empty
      end

      after do
        File.delete(file_path)
      end
    end

    it 'writes files out over sftp' do
      expect(EducationBenefitsClaim.unprocessed).not_to be_empty
      ClimateControl.modify EDU_SFTP_HOST: 'localhost', EDU_SFTP_PASS: 'test' do
        sftp_session_mock = double
        sftp_mock = double(session: sftp_session_mock)

        expect(Net::SFTP).to receive(:start).once.and_return(sftp_mock)
        expect(sftp_mock).to receive(:upload!) do |contents, path|
          expect(path).to eq filename
          expect(contents.read).to include('EDUCATION BENEFIT BEING APPLIED FOR: Chapter 1606')
        end
        expect(sftp_mock.session).to receive(:close)
        expect { subject.perform }.to trigger_statsd_gauge(
          'worker.education_benefits_claim.transmissions',
          value: 2,
          tags: [
            'rpo:307',
            'form:22-1990'
          ]
        )

        expect(EducationBenefitsClaim.unprocessed).to be_empty
      end
    end
  end
end
