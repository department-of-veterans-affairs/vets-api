# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::CreateDailySpoolFiles, type: :model, form: :education_benefits do
  subject { described_class.new }

  let!(:application_1606) do
    FactoryGirl.create(:education_benefit_claim)
  end

  context '#format_application' do
    it 'uses conformant sample data in the tests' do
      expect(application_1606.form).to match_vets_schema('edu-benefits-schema')
    end

    # TODO: Does it make sense to check against a known-good submission? Probably.
    it 'formats a 22-1990 submission in textual form' do
      result = subject.format_application(application_1606.open_struct_form)
      expect(result).to include("*INIT*\r\nMARK\r\n\r\nOLSON")
      expect(result).to include('Name:   Mark Olson')
      expect(result).to include('EDUCATION BENEFIT BEING APPLIED FOR: Chapter 1606')
    end

    it 'outputs a valid spool file fragment' do
      result = subject.format_application(application_1606.open_struct_form)
      expect(result.lines.select { |line| line.length > 80 }).to be_empty
    end
  end

  context '#group_submissions_by_region' do
    it 'takes a list of records into chunked forms' do
      eastern = EducationBenefitsClaim.new(form: { schoolAddress: { state: 'MD' } }.to_json)
      eastern_default = EducationBenefitsClaim.new(form: {}.to_json)
      western = EducationBenefitsClaim.new(form: { address: { state: 'APO/FPO AP' } }.to_json)

      output = subject.group_submissions_by_region([eastern, eastern_default, western])
      expect(output[:eastern].length).to be(2)
      expect(output[:western].length).to be(1)
    end
  end

  context 'create_files' do
    it 'writes files out over sftp' do
      mock_file = double(File)
      mock_writer = StringIO.new
      sftp_mock = double(file: mock_file)
      Net::SFTP.stub(:start).and_yield(sftp_mock)
      expect(mock_file).to receive('open').with('2016-09-16-eastern.spl', 'w').and_return(mock_writer)
      subject.run(application_1606.created_at)
      # read back the written file
      mock_writer.rewind
      expect(mock_writer.read).to include('EDUCATION BENEFIT BEING APPLIED FOR: Chapter 1606')
    end
  end
end
