# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::CreateDailySpoolFiles, type: :model, form: :education_benefits do
  subject { described_class.new }

  let(:application_1606) do
    FactoryGirl.create(:education_benefit_claim)
  end

  context '#format_application' do
    it 'uses conformant sample data in the tests' do
      expect(application_1606.form).to match_vets_schema('edu-benefits-schema')
    end

    # TODO: Does it make sense to check against a known-good submission? Probably.
    it 'formats a 22-1990 submission in textual form' do
      result = subject.format_application(application_1606)
      expect(result).to include("*INIT*\r\nMARK\r\n\r\nOLSON")
      expect(result).to include('Name:   Mark Olson')
      expect(result).to include('EDUCATION BENEFIT BEING APPLIED FOR: Chapter 1606')
    end

    it 'outputs a valid spool file fragment' do
      result = subject.format_application(application_1606)
      expect(result.lines.select { |line| line.length > 80 }).to be_empty
    end
  end

  it 'writes out spool files' do
    expect(Tempfile).to receive(:create).once # should be 4 times by the time we're done
    subject.run
  end
end
