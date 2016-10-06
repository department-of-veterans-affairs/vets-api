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
      expect(application_1606.form).to match_vets_schema('education_benefits')
    end

    context 'conformance' do
      basepath = Rails.root.join('spec', 'fixtures', 'education_benefits_claims')
      SAMPLE_APPLICATIONS.each do |application_name|
        it "generates #{application_name} correctly" do
          json = File.read(File.join(basepath, "#{application_name}.json"))
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
      eastern = EducationBenefitsClaim.new(form: { school: { address: { state: 'MD' } } }.to_json)
      southern = EducationBenefitsClaim.new(form: { school: { address: { state: 'GA' } } }.to_json)
      central = EducationBenefitsClaim.new(form: { veteranAddress: { state: 'WI' } }.to_json)
      eastern_default = EducationBenefitsClaim.new(form: {}.to_json)
      western = EducationBenefitsClaim.new(form: { veteranAddress: { state: 'APO/FPO AP' } }.to_json)

      output = subject.group_submissions_by_region([eastern, central, southern, eastern_default, western])
      expect(output[:eastern].length).to be(2)
      expect(output[:western].length).to be(1)
      expect(output[:southern].length).to be(1)
      expect(output[:central].length).to be(1)
    end
  end

  context 'create_files' do
    def perform_with_frozen_time
      Timecop.freeze(Time.zone.parse('2016-09-16 03:00:00 EDT')) do
        subject.perform
      end
    end

    let(:filename) { '2016-09-16-eastern.spl' }

    context 'in the development env' do
      let(:file_path) { "tmp/spool_files/#{filename}" }

      before do
        expect(Rails.env).to receive('development?').once { true }
      end

      it 'writes a file to the tmp dir' do
        perform_with_frozen_time
        expect(File.read(file_path).include?('APPLICATION FOR VA EDUCATION BENEFITS')).to eq(true)
      end

      after do
        File.delete(file_path)
      end
    end

    it 'writes files out over sftp' do
      mock_file = double(File)
      mock_writer = StringIO.new
      sftp_mock = double(file: mock_file)
      expect(Net::SFTP).to receive(:start).once.and_yield(sftp_mock)
      expect(mock_file).to receive('open').with(filename, 'w').and_return(mock_writer)
      expect(mock_writer).to receive('close').once
      perform_with_frozen_time

      # read back the written file
      mock_writer.rewind
      expect(mock_writer.read).to include('EDUCATION BENEFIT BEING APPLIED FOR: Chapter 1606')
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
