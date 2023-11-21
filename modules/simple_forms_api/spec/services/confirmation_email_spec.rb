# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::ConfirmationEmail do
  describe '21_10210' do
    let(:data) do
      fixture_path = Rails.root.join(
        'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_10210.json'
      )
      JSON.parse(fixture_path.read)
    end

    describe 'users own claim' do
      it 'is a veteran' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        data['claim_ownership'] = 'self'
        data['claimant_type'] = 'veteran'

        subject = described_class.new(form_data: data, form_number: 'vba_21_10210',
                                      confirmation_number: 'confirmation_number')

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'veteran.longemail@email.com',
          'form21_10210_confirmation_email_template_id',
          {
            'first_name' => 'JOHN',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => 'confirmation_number'
          }
        )
      end

      it 'is not a veteran' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        data['claim_ownership'] = 'self'
        data['claimant_type'] = 'non-veteran'

        subject = described_class.new(form_data: data, form_number: 'vba_21_10210',
                                      confirmation_number: 'confirmation_number')

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'claimant.long@address.com',
          'form21_10210_confirmation_email_template_id',
          {
            'first_name' => 'JOE',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => 'confirmation_number'
          }
        )
      end
    end

    describe 'someone elses claim' do
      it 'claimant is a veteran' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        data['claim_ownership'] = 'third-party'
        data['claimant_type'] = 'veteran'

        subject = described_class.new(form_data: data, form_number: 'vba_21_10210',
                                      confirmation_number: 'confirmation_number')

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'my.long.email.address@email.com',
          'form21_10210_confirmation_email_template_id',
          {
            'first_name' => 'JACK',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => 'confirmation_number'
          }
        )
      end

      it 'claimant is not a veteran' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        data['claim_ownership'] = 'third-party'
        data['claimant_type'] = 'non-veteran'

        subject = described_class.new(form_data: data, form_number: 'vba_21_10210',
                                      confirmation_number: 'confirmation_number')

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'my.long.email.address@email.com',
          'form21_10210_confirmation_email_template_id',
          {
            'first_name' => 'JACK',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => 'confirmation_number'
          }
        )
      end
    end
  end

  describe '21_0845' do
    let(:data) do
      fixture_path = Rails.root.join(
        'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_0845.json'
      )
      JSON.parse(fixture_path.read)
    end

    describe 'signed in user' do
      it 'non-veteran authorizer' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        data['authorizer_email'] = 'authorizer_email@example.com'

        subject = described_class.new(
          form_data: data,
          form_number: 'vba_21_0845',
          confirmation_number: 'confirmation_number',
          user: create(:user)
        )

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'authorizer_email@example.com',
          'form21_0845_confirmation_email_template_id',
          {
            'first_name' => 'JACK',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => 'confirmation_number'
          }
        )
      end

      it 'veteran authorizer' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        data['authorizer_type'] = 'veteran'

        subject = described_class.new(
          user: create(:user),
          form_data: data,
          form_number: 'vba_21_0845',
          confirmation_number: 'confirmation_number'
        )

        allow(subject.user).to receive(:va_profile_email).and_return('abraham.lincoln@vets.gov')

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'abraham.lincoln@vets.gov',
          'form21_0845_confirmation_email_template_id',
          {
            'first_name' => 'JOHN',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => 'confirmation_number'
          }
        )
      end
    end

    describe 'not signed in user' do
      it 'non-veteran authorizer' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        # form requires email
        data['authorizer_email'] = 'authorizer_email@example.com'

        subject = described_class.new(
          form_data: data,
          form_number: 'vba_21_0845',
          confirmation_number: 'confirmation_number'
        )

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'authorizer_email@example.com',
          'form21_0845_confirmation_email_template_id',
          {
            'first_name' => 'JACK',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => 'confirmation_number'
          }
        )
      end

      it 'veteran authorizer' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        # form does not require email
        data['authorizer_type'] = 'veteran'

        subject = described_class.new(
          form_data: data,
          form_number: 'vba_21_0845',
          confirmation_number: 'confirmation_number'
        )

        subject.send

        expect(VANotify::EmailJob).not_to have_received(:perform_async)
      end
    end
  end
end
