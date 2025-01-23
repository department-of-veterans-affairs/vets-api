# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1995 do
  subject { described_class.new(education_benefits_claim) }

  let(:education_benefits_claim) { build(:va1995).education_benefits_claim }

  before do
    allow(Flipper).to receive(:enabled?).and_call_original
    allow(Flipper).to receive(:enabled?).with(:validate_saved_claims_with_json_schemer).and_return(false)
  end

  # For each sample application we have, format it and compare it against a 'known good'
  # copy of that submission. This technically covers all the helper logic found in the
  # `Form` specs, but are a good safety net for tracking how forms change over time.
  %i[
    minimal kitchen_sink kitchen_sink_blank_appliedfor kitchen_sink_blank_appliedfor_ch30
    kitchen_sink_ch35_ch33 kitchen_sink_ch35_ch35 ch33_post911 ch33_fry ch30 ch1606
    kitchen_sink_ch33_p911_baf ch33_p911_to_fry ch33_fry_baf ch30_mgi_bill ch1606_baf toe
    toe_baf
  ].each do |application_name|
    test_spool_file('1995', application_name)
  end

  # run PROD_EMULATION=true rspec spec/sidekiq/education_form/forms/va1995_spec.rb to
  # emulate production (e.g. when removing feature flags)
  prod_emulation = true if ENV['PROD_EMULATION'].eql?('true')

  # :nocov:
  context 'test 1995 - production emulation', if: prod_emulation do
    before do
      allow(Settings).to receive(:vsp_environment).and_return('vagov-production')
    end

    %i[minimal kitchen_sink kitchen_sink_blank_appliedfor kitchen_sink_blank_appliedfor_ch30 kitchen_sink_ch35_ch33
       kitchen_sink_ch35_ch35 ch33_post911 ch33_fry ch30 ch1606].each do |application_name|
      test_spool_file('1995', application_name)
    end
  end
  # :nocov:

  describe '#direct_deposit_type' do
    let(:education_benefits_claim) { create(:va1995_full_form).education_benefits_claim }

    it 'converts internal keys to text' do
      expect(subject.direct_deposit_type('startUpdate')).to eq('Start or Update')
      expect(subject.direct_deposit_type('stop')).to eq('Stop')
      expect(subject.direct_deposit_type('noChange')).to eq('Do Not Change')
    end
  end

  # :nocov:
  describe '#direct_deposit_type - production emulation', if: prod_emulation do
    before do
      allow(Settings).to receive(:vsp_environment).and_return('vagov-production')
    end

    let(:education_benefits_claim) { create(:va1995_full_form).education_benefits_claim }

    it 'converts internal keys to text' do
      expect(subject.direct_deposit_type('startUpdate')).to eq('Start or Update')
      expect(subject.direct_deposit_type('stop')).to eq('Stop')
      expect(subject.direct_deposit_type('noChange')).to eq('Do Not Change')
    end
  end
  # :nocov:

  context 'spool_file tests with high school minors' do
    %w[
      ch30_guardian_not_graduated
      ch30_guardian_graduated_sponsor
      ch30_guardian_graduated
    ].each do |test_application|
      test_spool_file('1995', test_application)
    end
  end

  # :nocov:
  context 'spool_file tests with high school minors - production emulation', if: prod_emulation do
    before do
      allow(Settings).to receive(:vsp_environment).and_return('vagov-production')
    end

    %w[
      ch30_guardian_not_graduated
      ch30_guardian_graduated_sponsor
      ch30_guardian_graduated
    ].each do |test_application|
      test_spool_file('1995', test_application)
    end
  end
  # :nocov:
end
