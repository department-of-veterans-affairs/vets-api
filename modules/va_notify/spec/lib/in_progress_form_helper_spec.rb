# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/in_progress_form_helper'

describe VANotify::InProgressFormHelper do
  describe '686c' do
    let(:in_progress_form) { create(:in_progress_686c_form) }

    it 'knows the template id' do
      expect(described_class::TEMPLATE_ID.fetch('686C-674')).to eq('fake_template_id')
    end

    it 'knows the friendly summary' do
      summary = 'Application Request to Add or Remove Dependents'
      expect(described_class::FRIENDLY_FORM_SUMMARY.fetch('686C-674')).to eq(summary)
    end

    it '#veteran_data returns an instance of VANotify::Veteran' do
      expect(described_class.veteran_data(in_progress_form)).to be_a VANotify::Veteran
    end
  end

  describe '1010ez' do
    let(:in_progress_form) { create(:in_progress_1010ez_form) }

    it 'knows the template id' do
      expect(described_class::TEMPLATE_ID.fetch('1010ez')).to eq('fake_template_id')
    end

    it 'knows the friendly summary' do
      expect(described_class::FRIENDLY_FORM_SUMMARY.fetch('1010ez')).to eq('Application for Health Benefits')
    end

    it '#veteran_data returns an instance of VANotify::Veteran' do
      expect(described_class.veteran_data(in_progress_form)).to be_a VANotify::Veteran
    end
  end
end
