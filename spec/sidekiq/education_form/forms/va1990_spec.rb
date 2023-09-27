# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1990, type: :model, form: :education_benefits do
  subject { described_class.new(application) }

  let(:application) { FactoryBot.create(:va1990).education_benefits_claim }

  # For each sample application we have, format it and compare it against a 'known good'
  # copy of that submission. This technically covers all the helper logic found in the
  # `Form` specs, but are a good safety net for tracking how forms change over time.
  %i[simple_ch33 kitchen_sink kitchen_sink_edu_prog kitchen_sink_active_duty].each do |application_name|
    test_spool_file('1990', application_name)
  end

  describe '#rotc_scholarship_amounts' do
    it 'always outputs 5 double-spaced lines' do
      output = subject.rotc_scholarship_amounts(nil)
      expect(output.lines.count).to eq(9)
      (1..5).each do |i|
        expect(output).to include "Year #{i}"
      end
    end

    it 'includes partial records' do
      values = [OpenStruct.new(amount: 1), OpenStruct.new(amount: 2), OpenStruct.new(amount: 3)]
      output = subject.rotc_scholarship_amounts(values)
      expect(output.lines.count).to eq(9)
      (1..3).each do |i|
        expect(output).to include "Year #{i}"
        expect(output).to include "Amount: #{i}"
      end
      expect(output).to include 'Year 4'
      expect(output).to include 'Year 5'
    end
  end

  describe '#disclosure_for', run_at: '2017-01-04 03:00:00 EDT' do
    today = '2017-01-04'
    before do
      subject.instance_variable_set(:@applicant, OpenStruct.new(benefitsRelinquishedDate: Time.zone.today))
    end

    { CH32: 'Chapter 32',
      CH30: 'Chapter 30',
      CH1606: 'Chapter 1606',
      CH33: 'Chapter 33 - Not Eligible for Other Listed Benefits',
      CH33_1606: "Chapter 33 in Lieu of Chapter 1606 - Effective: #{today}",
      CH33_1607: "Chapter 33 in Lieu of Chapter 1607 - Effective: #{today}",
      CH33_30: "Chapter 33 in Lieu of Chapter 30 - Effective: #{today}" }.each do |type, check|
      it "shows a partial containing the #{type} disclaimer" do
        output = subject.disclosure_for(type)
        expect(output).to include(check)
      end
    end
  end

  describe '#disclosures' do
    it 'adds disclosures for different types' do
      expect(subject).to receive(:disclosure_for).with('CH30')
      expect(subject).to receive(:disclosure_for).with('CH32')
      expect(subject).to receive(:disclosure_for).with('CH33')
      expect(subject).to receive(:disclosure_for).with('CH1606')
      subject.disclosures(OpenStruct.new(chapter1606: true, chapter30: true, chapter32: true, chapter33: true))
    end

    it 'handles chapter 33 relinquishments' do
      expect(subject).to receive(:disclosure_for).with('CH33_1606')
      subject.disclosures(OpenStruct.new(chapter33: true, benefitsRelinquished: 'chapter1606'))
    end
  end

  context 'spool_file tests with guardian' do
    %w[
      kitchen_sink_active_duty_guardian_graduated
      kitchen_sink_active_duty_guardian_not_graduated
    ].each do |test_application|
      test_spool_file('1990', test_application)
    end
  end
end
