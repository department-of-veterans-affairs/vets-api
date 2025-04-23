# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::CreateDailySpoolFiles, form: :education_benefits, type: :model do
  subject { described_class.new }

  let!(:application_1606) do
    create(:va1990).education_benefits_claim
  end
  let(:line_break) { EducationForm::CreateDailySpoolFiles::WINDOWS_NOTEPAD_LINEBREAK }

  before do
    allow(Flipper).to receive(:enabled?).and_call_original
  end

  after(:all) do
    FileUtils.rm_rf('tmp/spool_files')
  end

  context 'scheduling' do
    before do
      allow(Rails.env).to receive('development?').and_return(true)
    end

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
        sidekiq_file = Rails.root.join('lib', 'periodic_jobs.rb')
        lines = File.readlines(sidekiq_file).grep(/EducationForm::CreateDailySpoolFiles/i)
        cron = lines.first.gsub("  mgr.register('", '').gsub("', 'EducationForm::CreateDailySpoolFiles')\n", '')
        scheduler.schedule_cron(cron) {} # schedule_cron requires a block
      end

      it 'is only triggered by sidekiq-scheduler on weekdays' do
        scheduler_data = scheduler.jobs.first.cron_line
        expect(scheduler_data.hours).to eq([3])
        expect(scheduler_data.weekdays).to eq([[1], [2], [3], [4], [5]])
      end

      it 'skips observed holidays' do
        expect(Flipper).to receive(:enabled?).with(:spool_testing_error_2).and_return(false).at_least(:once)

        possible_runs.each do |day, should_run|
          Timecop.freeze(Time.zone.parse(day.to_s).beginning_of_day) do
            expect(subject.perform).to be(should_run)
          end
        end
      end
    end

    it 'logs a message on holidays', run_at: '2017-01-02 03:00:00 EDT' do
      expect(subject).not_to receive(:write_files)
      expect(subject).to receive('log_info').with("Skipping on a Holiday: New Year's Day")
      expect(subject.perform).to be false
    end

    it 'does not skip informal holidays', run_at: '2017-04-01 03:00:00 EDT' do
      # Sanity check that this *is* an informal holiday we're testing
      expect(Holidays.on(Time.zone.today, :us, :informal).first[:name]).to eq("April Fool's Day")
      expect(Flipper).to receive(:enabled?).with(:spool_testing_error_2).and_return(false).at_least(:once)
      expect(subject).to receive(:write_files)
      expect(subject.perform).to be true
    end
  end

  describe '#format_application' do
    context 'with a 1990 form' do
      it 'tracks and returns a form object' do
        expect(subject).to receive(:track_form_type).with('22-1990', 999)
        result = subject.format_application(application_1606, rpo: 999)
        expect(result).to be_a(EducationForm::Forms::VA1990)
      end
    end

    context 'with a 1995 form' do
      let(:application_1606) { create(:va1995_full_form).education_benefits_claim }

      it 'tracks the 1995 form' do
        expect(subject).to receive(:track_form_type).with('22-1995', 999)
        result = subject.format_application(application_1606, rpo: 999)
        expect(result).to be_a(EducationForm::Forms::VA1995)
      end
    end

    context 'result tests' do
      subject { described_class.new.format_application(application_1606).text }

      it 'outputs a valid spool file fragment' do
        expect(subject.lines.select { |line| line.length > 80 }).to be_empty
      end

      it 'contains only windows-style newlines' do
        expect(subject).not_to match(/([^\r]\n)/)
      end
    end
  end

  describe '#perform' do
    context 'with a mix of valid and invalid record', run_at: '2016-09-16 03:00:00 EDT' do
      let(:spool_files) { Rails.root.join('tmp', 'spool_files', '*') }

      before do
        allow(Rails.env).to receive('development?').and_return(true)
        application_1606.saved_claim.form = {}.to_json
        application_1606.saved_claim.save!(validate: false) # Make this claim super malformed
        create(:va1990_western_region)
        create(:va1995_full_form)
        create(:va0994_full_form)
        # clear out old test files
        FileUtils.rm_rf(Dir.glob(spool_files))
        # ensure our test data is spread across 2 regions..
        expect(EducationBenefitsClaim.unprocessed.pluck(:regional_processing_office).uniq.count).to eq(2)
      end

      it 'processes the valid messages' do
        expect(Flipper).to receive(:enabled?).with(any_args).and_return(false).at_least(:once)
        expect { subject.perform }.to change { EducationBenefitsClaim.unprocessed.count }.from(4).to(0)
        expect(Dir[spool_files].count).to eq(2)
      end
    end

    context 'with records in staging', run_at: '2016-09-16 03:00:00 EDT' do
      before do
        application_1606.saved_claim.form = {}.to_json
        create(:va1990_western_region)
        create(:va1995_full_form)
        create(:va0994_full_form)
        ActionMailer::Base.deliveries.clear
      end

      it 'processes the valid messages' do
        with_settings(Settings, hostname: 'staging-api.va.gov') do
          expect(Flipper).to receive(:enabled?).with(any_args).and_return(false).at_least(:once)
          expect { subject.perform }.to change { EducationBenefitsClaim.unprocessed.count }.from(4).to(0)
          expect(ActionMailer::Base.deliveries.count).to be > 0
        end
      end
    end

    context 'with records in production', run_at: '2016-09-16 03:00:00 EDT' do
      before do
        allow(Settings).to receive(:hostname).and_return('api.va.gov')
        application_1606.saved_claim.form = {}.to_json
        create(:va1990_western_region)
        create(:va1995_full_form)
        create(:va0994_full_form)
        ActionMailer::Base.deliveries.clear
      end

      it 'does not process the valid messages' do
        expect(Flipper).to receive(:enabled?).with(any_args).and_return(false).at_least(:once)
        expect { subject.perform }.to change { EducationBenefitsClaim.unprocessed.count }.from(4).to(0)
        expect(ActionMailer::Base.deliveries.count).to be 0
      end
    end

    context 'with no records', run_at: '2016-09-16 03:00:00 EDT' do
      before do
        EducationBenefitsClaim.delete_all
      end

      it 'prints a statement and exits', run_at: '2017-02-21 00:00:00 EDT' do
        expect(subject).not_to receive(:write_files)
        expect(subject).to receive('log_info').with('No records to process.').once
        expect(subject.perform).to be(true)
      end

      it 'notifies slack', run_at: '2017-02-21 00:00:00 EDT' do
        expect(Flipper).to receive(:enabled?).with(:spool_testing_error_2).and_return(true).once

        expect_any_instance_of(SlackNotify::Client).to receive(:notify)

        with_settings(Settings.edu,
                      audit_enabled: true,
                      slack: OpenStruct.new(webhook_url: 'https://example.com')) do
          described_class.new.perform
        end
      end
    end
  end

  describe '#group_submissions_by_region' do
    it 'takes a list of records into chunked forms' do
      base_form = {
        veteranFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        privacyAgreementAccepted: true
      }
      base_address = { street: 'A', city: 'B', country: 'USA' }
      submissions = []

      [
        { state: 'MD' },
        { state: 'GA' },
        { state: 'WI' },
        { state: 'OK' },
        { state: 'XX', country: 'PHL' }
      ].each do |address_data|
        submissions << SavedClaim::EducationBenefits::VA1990.create(
          form: base_form.merge(
            educationProgram: {
              address: base_address.merge(address_data)
            }
          ).to_json
        ).education_benefits_claim
      end

      submissions << SavedClaim::EducationBenefits::VA1990.create(
        form: base_form.to_json
      ).education_benefits_claim

      output = subject.group_submissions_by_region(submissions)

      expect(output[:eastern].length).to be(3)
      expect(output[:western].length).to be(3)
    end
  end

  context 'write_files', run_at: '2016-09-17 03:00:00 EDT' do
    let(:filename) { '307_09172016_070000_vetsgov.spl' }
    let!(:second_record) { create(:va1995) }

    context 'in the development env' do
      let(:file_path) { "tmp/spool_files/#{filename}" }

      before do
        expect(Rails.env).to receive('development?').once.and_return(true)
        expect(Flipper).to receive(:enabled?).with(any_args).and_return(false).at_least(:once)
      end

      after do
        File.delete(file_path)
      end

      it 'writes a file to the tmp dir' do
        expect(EducationBenefitsClaim.unprocessed).not_to be_empty
        subject.perform
        contents = File.read(file_path)
        expect(contents).to include('APPLICATION FOR VA EDUCATION BENEFITS')
        # Concatenation is done in #write_files, so check for it here in the caller
        expect(contents).to include("*END*#{line_break}*INIT*")
        expect(contents).to include(second_record.education_benefits_claim.confirmation_number)
        expect(contents).to include(application_1606.confirmation_number)
        expect(EducationBenefitsClaim.unprocessed).to be_empty
      end
    end

    context 'on first retry attempt with a previous success' do
      let(:file_path) { "tmp/spool_files/#{filename}" }

      before do
        expect(Rails.env).to receive('development?').twice.and_return(true)
        expect(Flipper).to receive(:enabled?).with(:spool_testing_error_2).and_return(false).at_least(:once)
      end

      after do
        File.delete(file_path)
      end

      it 'notifies file was already created for filename and RPO' do
        expect(EducationBenefitsClaim.unprocessed).not_to be_empty
        subject.perform

        create(:va1995)
        expect(subject).to receive(:log_info).once

        msg = 'A spool file for 307 on 09172016 was already created'
        expect(subject).to receive(:log_info).with(msg)
        subject.perform
      end
    end

    context 'notifies which file failed during initial attempt' do
      let(:file_path) { "tmp/spool_files/#{filename}" }

      before do
        expect(Rails.env).to receive('development?').and_return(true).at_least(:once)
        expect(Flipper).to receive(:enabled?).with(:spool_testing_error_3).and_return(false).at_least(:once)
        expect(Flipper).to receive(:enabled?).with(:spool_testing_error_2).and_return(false).at_least(:once)
      end

      it 'logs exception to sentry' do
        local_mock = instance_double(SFTPWriter::Local)

        expect(EducationBenefitsClaim.unprocessed).not_to be_empty
        expect(SFTPWriter::Local).to receive(:new).exactly(6).and_return(local_mock)
        expect(local_mock).to receive(:write).exactly(6).times.and_raise('boom')
        expect(local_mock).to receive(:close).once.and_return(true)
        expect(subject).to receive(:log_exception_to_sentry).exactly(6)
                                                            .times.with(instance_of(EducationForm::DailySpoolFileError))

        subject.perform
      end
    end

    context 'in the production env' do
      it 'writes files out over sftp' do
        # we're only pushing spool files on production, b/c of issues with staging data getting into TIMS at RPO's
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Settings).to receive(:hostname).and_return('api.va.gov')
        expect(EducationBenefitsClaim.unprocessed).not_to be_empty
        expect(Flipper).to receive(:enabled?).with(any_args).and_return(false).at_least(:once)

        # any readable file will work for this spec
        key_path = Rails.root.join(*'/spec/fixtures/files/idme_cert.crt'.split('/')).to_s
        with_settings(Settings.edu.sftp, host: 'localhost', key_path:) do
          session_mock = instance_double(Net::SSH::Connection::Session)

          sftp_mock = instance_double(Net::SFTP::Session, session: session_mock)
          expect(Net::SFTP).to receive(:start).once.and_return(sftp_mock)
          expect(sftp_mock).to receive(:open?).once.and_return(true)
          expect(sftp_mock).to receive(:mkdir!).with('spool_files').once.and_return(true)
          expect(sftp_mock).to receive(:upload!) do |contents, path|
            expect(path).to eq File.join(Settings.edu.sftp.relative_path, filename)
            expect(contents.read).to include('EDUCATION BENEFIT BEING APPLIED FOR: Chapter 1606')
          end
          expect(sftp_mock).to receive(:stat!).with(anything).and_return(4619)
          expect(session_mock).to receive(:close)

          expect { subject.perform }.to trigger_statsd_gauge(
            'worker.education_benefits_claim.transmissions.307.22-1990',
            value: 1
          ).and trigger_statsd_gauge(
            'worker.education_benefits_claim.transmissions.307.22-1995',
            value: 1
          )

          expect(EducationBenefitsClaim.unprocessed).to be_empty
        end
      end

      # rubocop:disable RSpec/NoExpectationExample
      it 'notifies the slack channel with a warning if no files were written' do
        stub_env_and_writer(
          byte_count: 0,
          expected_message: 'Warning: Uploaded 0 bytes to region: eastern'
        )
      end
      # rubocop:enable RSpec/NoExpectationExample

      def stub_env_and_writer(byte_count:, expected_message:)
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Settings).to receive(:hostname).and_return('api.va.gov')
        expect(EducationBenefitsClaim.unprocessed).not_to be_empty

        key_path = Rails.root.join('spec', 'fixtures', 'files', 'idme_cert.crt').to_s
        with_settings(Settings.edu.sftp, host: 'localhost', key_path:) do
          sftp_writer_mock = instance_double(SFTPWriter::Remote)

          allow(SFTPWriter::Factory).to receive(:get_writer).with(Settings.edu.sftp).and_return(SFTPWriter::Remote)
          allow(SFTPWriter::Remote)
            .to receive(:new)
            .with(Settings.edu.sftp, logger: anything)
            .and_return(sftp_writer_mock)

          allow(sftp_writer_mock).to receive(:write).once.and_return(byte_count)
          allow(sftp_writer_mock).to receive(:close).once.and_return(true)

          instance = described_class.new
          # allow is needed because it's called multiple times and expect fails without it
          allow(instance).to receive(:log_to_slack)
          expect(instance).to receive(:log_to_slack).with(include(expected_message))

          instance.perform
        end
      end
    end
  end
end
