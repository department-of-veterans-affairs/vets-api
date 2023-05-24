# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1995 do
  subject { described_class.new(education_benefits_claim) }

  let(:education_benefits_claim) { build(:va1995).education_benefits_claim }

  # For each sample application we have, format it and compare it against a 'known good'
  # copy of that submission. This technically covers all the helper logic found in the
  # `Form` specs, but are a good safety net for tracking how forms change over time.
  %i[minimal kitchen_sink ch33_post911 ch33_fry].each do |application_name|
    test_spool_file('1995', application_name)
  end

  describe '#direct_deposit_type' do
    let(:education_benefits_claim) { create(:va1995_full_form).education_benefits_claim }

    it 'converts internal keys to text' do
      expect(subject.direct_deposit_type('startUpdate')).to eq('Start or Update')
      expect(subject.direct_deposit_type('stop')).to eq('Stop')
      expect(subject.direct_deposit_type('noChange')).to eq('Do Not Change')
    end
  end
end
