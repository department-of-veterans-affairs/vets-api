# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::EducationBenefits do
  describe '.form_class' do
    it 'raises an error if the form_type is invalid' do
      expect { described_class.form_class('foo') }.to raise_error('Invalid form type')
    end

    it 'returns the form class for a form type' do
      expect(described_class.form_class('1990')).to eq(SavedClaim::EducationBenefits::VA1990)
    end
  end

  describe '#in_progress_form_id' do
    it 'returns form_id' do
      form = create(:va1990)
      expect(form.in_progress_form_id).to eq(form.form_id)
    end
  end

  describe '#after_submit' do
    let(:user) { create(:user) }

    describe 'sends confirmation email for the 5490' do
      it 'chapter 33' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va5490_chapter33)
        confirmation_number = subject.education_benefits_claim.confirmation_number

        subject.after_submit(user)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'email@example.com',
          'form5490_confirmation_email_template_id',
          {
            'first_name' => 'MARK',
            'benefit' => 'The Fry Scholarship (Chapter 33)',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number
          }
        )
      end

      it 'chapter 35' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = create(:va5490)
        confirmation_number = subject.education_benefits_claim.confirmation_number

        subject.after_submit(user)

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'email@example.com',
          'form5490_confirmation_email_template_id',
          {
            'first_name' => 'MARK',
            'benefit' => 'Survivors’ and Dependents’ Educational Assistance (DEA, Chapter 35)',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number
          }
        )
      end
    end
  end
end
