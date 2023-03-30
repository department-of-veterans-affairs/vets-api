# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/in_progress_form_helper'

describe VANotify::InProgressFormHelper do
  describe '686c' do
    let(:in_progress_form) { create_in_progress_form_days_ago(49, form_id: '686C-674') }

    it 'knows the template id' do
      expect(described_class::TEMPLATE_ID.fetch('686C-674')).to eq('fake_template_id')
    end

    it 'knows the friendly summary' do
      summary = 'Application Request to Add or Remove Dependents'
      expect(described_class::FRIENDLY_FORM_SUMMARY.fetch('686C-674')).to eq(summary)
    end
  end

  describe '.form_age' do
    it '7 days ago' do
      in_progress_form = create_in_progress_form_days_ago(7, form_id: '686C-674')
      expect(described_class.form_age(in_progress_form)).to eq('&7_days')
    end

    it 'defaults to empty string' do
      in_progress_form = create_in_progress_form_days_ago(6, form_id: '686C-674')
      expect(described_class.form_age(in_progress_form)).to eq('')
    end
  end

  describe '1010ez' do
    let(:in_progress_form) { create(:in_progress_1010ez_form, updated_at: 7.days.ago) }

    it 'knows the template id' do
      expect(described_class::TEMPLATE_ID.fetch('1010ez')).to eq('fake_template_id')
    end

    it 'knows the friendly summary' do
      expect(described_class::FRIENDLY_FORM_SUMMARY.fetch('1010ez')).to eq('Application for Health Benefits')
    end
  end

  def create_in_progress_form_days_ago(count, form_id:)
    Timecop.freeze(count.days.ago)
    in_progress_form = create(:in_progress_form, form_id:)
    Timecop.return
    in_progress_form
  end
end
