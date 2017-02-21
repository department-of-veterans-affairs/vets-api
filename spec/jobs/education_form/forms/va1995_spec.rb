# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1995 do
  let(:education_benefits_claim) { build(:education_benefits_claim_1995) }

  subject { described_class.new(education_benefits_claim) }

  SAMPLE_APPLICATIONS = [
    :minimal, :kitchen_sink
  ].freeze

  it 'has a 22-1995 type' do
    expect(described_class::TYPE).to eq('22-1995')
  end

  # For each sample application we have, format it and compare it against a 'known good'
  # copy of that submission. This technically covers all the helper logic found in the
  # `Form` specs, but are a good safety net for tracking how forms change over time.
  context '#text', run_at: '2016-10-06 03:00:00 EDT' do
    basepath = Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1995')
    SAMPLE_APPLICATIONS.each do |application_name|
      it "generates #{application_name} correctly" do
        json = File.read(File.join(basepath, "#{application_name}.json"))
        test_application = EducationBenefitsClaim.create!(form_type: 1995, form: json)
        allow(test_application).to receive(:id).and_return(1)

        result = described_class.new(test_application).text
        result.gsub!(EducationForm::WINDOWS_NOTEPAD_LINEBREAK, "\n")
        spl = File.read(File.join(basepath, "#{application_name}.spl"))

        expect(json).to match_vets_schema('change_of_program')
        expect(result).to eq(spl.rstrip)
      end
    end
  end

  context '#direct_deposit_type' do
    let(:education_benefits_claim) { create(:education_benefits_claim_1995_full_form) }
    it 'converts internal keys to text' do
      expect(subject.direct_deposit_type('startUpdate')).to eq('Start or Update')
      expect(subject.direct_deposit_type('stop')).to eq('Stop')
      expect(subject.direct_deposit_type('noChange')).to eq('Do Not Change')
    end
  end
end
