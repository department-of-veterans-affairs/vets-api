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
            'form:22-1990',
            'rpo:307'
          ]
        )

        expect(EducationBenefitsClaim.unprocessed).to be_empty
      end
    end
  end

  context '#full_address' do
    let(:address) { application_1606.open_struct_form.veteranAddress }

    subject { described_class.new.send(:full_address, address) }

    context 'with a nil address' do
      let(:address) { nil }

      it 'should return the blank string' do
        expect(subject).to eq('')
      end
    end

    context 'with no street2' do
      it 'should format the address correctly' do
        expect(subject).to eq("123 MAIN ST\nMILWAUKEE, WI, 53130\nUSA")
      end
    end

    context 'with a street2' do
      before do
        address.street2 = 'apt 2'
      end

      it 'should format the address correctly' do
        expect(subject).to eq("123 MAIN ST\nAPT 2\nMILWAUKEE, WI, 53130\nUSA")
      end
    end
  end
end
