# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::CreateDailySpoolFiles, type: :model, form: :education_benefits do
  subject { described_class.new }

  let!(:application_1606) do
    FactoryGirl.create(:education_benefits_claim)
  end
  let(:line_break) { described_class::WINDOWS_NOTEPAD_LINEBREAK }

  SAMPLE_APPLICATIONS = [
    :simple_ch33, :kitchen_sink
  ].freeze

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
    it 'uses conformant sample data in the tests' do
      expect(application_1606.form).to match_vets_schema('edu_benefits')
    end

    context 'conformance', run_at: '2016-10-06 03:00:00 EDT' do
      basepath = Rails.root.join('spec', 'fixtures', 'education_benefits_claims')
      SAMPLE_APPLICATIONS.each do |application_name|
        it "generates #{application_name} correctly" do
          json = File.read(File.join(basepath, "#{application_name}.json"))
          expect(json).to match_vets_schema('edu_benefits')
          application = EducationBenefitsClaim.new(form: json)
          result = subject.format_application(application.open_struct_form)
          spl = File.read(File.join(basepath, "#{application_name}.spl"))
          expect(result).to eq(spl)
        end
      end
    end

    context 'result tests' do
      subject { described_class.new.format_application(application_1606.open_struct_form) }

      # TODO: Does it make sense to check against a known-good submission? Probably.
      it 'formats a 22-1990 submission in textual form' do
        expect(subject).to include("*INIT*\r\nMARK\r\n\r\nOLSON")
        expect(subject).to include('Name:   Mark Olson')
        expect(subject).to include('EDUCATION BENEFIT BEING APPLIED FOR: Chapter 1606')
      end

      it 'outputs a valid spool file fragment' do
        expect(subject.lines.select { |line| line.length > 80 }).to be_empty
      end

      it 'includes the faa flight certificates' do
        expect(subject).to include("FAA Flight Certificates:#{line_break}cert1, cert2#{line_break}")
      end

      it 'includes the confirmation number' do
        expect(subject).to include("Confirmation #:  #{application_1606.confirmation_number}")
      end

      it "includes the veteran's postal code" do
        expect(subject).to include(application_1606.open_struct_form.veteranAddress.postalCode)
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

    context 'in the development env' do
      let(:file_path) { "tmp/spool_files/#{filename}" }

      before do
        expect(Rails.env).to receive('development?').once { true }
      end

      it 'writes a file to the tmp dir' do
        expect(EducationBenefitsClaim.unprocessed).not_to be_empty
        subject.perform
        expect(File.read(file_path).include?('APPLICATION FOR VA EDUCATION BENEFITS')).to eq(true)
        expect(EducationBenefitsClaim.unprocessed).to be_empty
      end

      after do
        File.delete(file_path)
      end
    end

    it 'writes files out over sftp' do
      expect(EducationBenefitsClaim.unprocessed).not_to be_empty
      ClimateControl.modify EDU_SFTP_HOST: 'localhost', EDU_SFTP_PASS: 'test' do
        sftp_mock = double
        expect(Net::SFTP).to receive(:start).once.and_yield(sftp_mock)
        expect(sftp_mock).to receive(:upload!) do |contents, path|
          expect(path).to eq filename
          expect(contents.read).to include('EDUCATION BENEFIT BEING APPLIED FOR: Chapter 1606')
        end

        expect { subject.perform }.to trigger_statsd_gauge(
          'worker.education_benefits_claim.transmissions',
          value: 1,
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
