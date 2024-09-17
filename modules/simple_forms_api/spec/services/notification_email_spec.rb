# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::NotificationEmail do
  %i[confirmation error received].each do |notification_type|
    describe '#send' do
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_10210.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:form_submission) { create(:form_submission, form_data: data.to_json, form_type: '21-10210') }
      let(:form_submission_attempt) { create(:form_submission_attempt, form_submission:) }

      context 'flipper is on' do
        before do
          allow(Flipper).to receive(:enabled?).and_return true
        end

        it 'sends the email' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          data['claim_ownership'] = 'self'
          data['claimant_type'] = 'veteran'

          subject = described_class.new(form_submission_attempt:, notification_type:)

          subject.send

          expect(VANotify::EmailJob).to have_received(:perform_async)
        end
      end

      context 'flipper is off' do
        before do
          allow(Flipper).to receive(:enabled?).and_return false
        end

        it 'does not send the email' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          subject = described_class.new(form_submission_attempt:, notification_type:)

          subject.send

          expect(VANotify::EmailJob).not_to have_received(:perform_async)
        end
      end
    end

    describe '21_10210' do
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_10210.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:form_submission) { create(:form_submission, form_data: data.to_json, form_type: '21-10210') }
      let(:form_submission_attempt) { create(:form_submission_attempt, form_submission:) }

      describe 'users own claim' do
        it 'is a veteran' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          data['claim_ownership'] = 'self'
          data['claimant_type'] = 'veteran'

          subject = described_class.new(form_submission_attempt:, notification_type:)

          subject.send

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            'veteran.longemail@email.com',
            "form21_10210_#{notification_type}_email_template_id",
            {
              'first_name' => 'JOHN',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
              'lighthouse_updated_at' => nil
            }
          )
        end

        it 'is not a veteran' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          data['claim_ownership'] = 'self'
          data['claimant_type'] = 'non-veteran'

          subject = described_class.new(form_submission_attempt:, notification_type:)

          subject.send

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            'claimant.long@address.com',
            "form21_10210_#{notification_type}_email_template_id",
            {
              'first_name' => 'JOE',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
              'lighthouse_updated_at' => nil
            }
          )
        end
      end

      describe 'someone elses claim' do
        it 'claimant is a veteran' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          data['claim_ownership'] = 'third-party'
          data['claimant_type'] = 'veteran'

          subject = described_class.new(form_submission_attempt:, notification_type:)

          subject.send

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            'my.long.email.address@email.com',
            "form21_10210_#{notification_type}_email_template_id",
            {
              'first_name' => 'JACK',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
              'lighthouse_updated_at' => nil
            }
          )
        end

        it 'claimant is not a veteran' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          data['claim_ownership'] = 'third-party'
          data['claimant_type'] = 'non-veteran'

          subject = described_class.new(form_submission_attempt:, notification_type:)

          subject.send

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            'my.long.email.address@email.com',
            "form21_10210_#{notification_type}_email_template_id",
            {
              'first_name' => 'JACK',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
              'lighthouse_updated_at' => nil
            }
          )
        end
      end
    end
  end

  describe '40_0247' do
    context 'when email is entered' do
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_40_0247.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:form_submission) { create(:form_submission, form_data: data.to_json, form_type: '40-0247') }
      let(:form_submission_attempt) { create(:form_submission_attempt, form_submission:) }

      it 'sends the confirmation email' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = described_class.new(form_submission_attempt:, notification_type: :confirmation)

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'a@b.com',
          'form40_0247_confirmation_email_template_id',
          {
            'first_name' => 'JOE',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
            'lighthouse_updated_at' => nil
          }
        )
      end
    end

    context 'when email is omitted' do
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_40_0247-min.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:form_submission) { create(:form_submission, form_data: data.to_json, form_type: '40-0247') }
      let(:form_submission_attempt) { create(:form_submission_attempt, form_submission:) }

      context 'when user is signed in' do
        let(:user) { create(:user, :loa3) }

        it 'does not send the confirmation email' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          expect(data['applicant_email']).to be_nil

          subject = described_class.new(form_submission_attempt:, notification_type: :confirmation)

          subject.send

          expect(VANotify::EmailJob).not_to have_received(:perform_async)
        end
      end

      context 'when user is not signed in' do
        it 'does not send the confirmation email' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          expect(data['applicant_email']).to be_nil

          subject = described_class.new(form_submission_attempt:, notification_type: :confirmation)

          subject.send

          expect(VANotify::EmailJob).not_to have_received(:perform_async)
        end
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
    let(:form_submission) { create(:form_submission, form_data: data.to_json, form_type: '21-0845') }
    let(:form_submission_attempt) { create(:form_submission_attempt, form_submission:) }

    describe 'signed in user' do
      it 'non-veteran authorizer' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        data['authorizer_email'] = 'authorizer_email@example.com'

        subject = described_class.new(form_submission_attempt:, notification_type: :confirmation, user: create(:user))

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'authorizer_email@example.com',
          'form21_0845_confirmation_email_template_id',
          {
            'first_name' => 'JACK',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
            'lighthouse_updated_at' => nil
          }
        )
      end

      it 'veteran authorizer' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        data['authorizer_type'] = 'veteran'

        subject = described_class.new(form_submission_attempt:, notification_type: :confirmation, user: create(:user))

        allow(subject.user).to receive(:va_profile_email).and_return('abraham.lincoln@vets.gov')

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'abraham.lincoln@vets.gov',
          'form21_0845_confirmation_email_template_id',
          {
            'first_name' => 'JOHN',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
            'lighthouse_updated_at' => nil
          }
        )
      end
    end

    describe 'not signed in user' do
      it 'non-veteran authorizer' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        # form requires email
        data['authorizer_email'] = 'authorizer_email@example.com'

        subject = described_class.new(form_submission_attempt:, notification_type: :confirmation)

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'authorizer_email@example.com',
          'form21_0845_confirmation_email_template_id',
          {
            'first_name' => 'JACK',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
            'lighthouse_updated_at' => nil
          }
        )
      end

      it 'veteran authorizer' do
        allow(VANotify::EmailJob).to receive(:perform_async)
        # form does not require email
        data['authorizer_type'] = 'veteran'

        subject = described_class.new(form_submission_attempt:, notification_type: :confirmation)

        subject.send

        expect(VANotify::EmailJob).not_to have_received(:perform_async)
      end
    end
  end

  describe '21_0966' do
    let(:data) do
      fixture_path = Rails.root.join(
        'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_0966.json'
      )
      JSON.parse(fixture_path.read)
    end
    let(:form_submission) { create(:form_submission, form_data: data.to_json, form_type: '21-0966') }
    let(:form_submission_attempt) { create(:form_submission_attempt, form_submission:) }
    let(:user) { create(:user, :loa3) }

    it 'sends the confirmation email' do
      allow(VANotify::EmailJob).to receive(:perform_async)

      subject = described_class.new(form_submission_attempt:, notification_type: :confirmation, user:)

      subject.send

      expect(VANotify::EmailJob).to have_received(:perform_async).with(
        user.va_profile_email,
        'form21_0966_confirmation_email_template_id',
        {
          'first_name' => user.first_name.upcase,
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
          'lighthouse_updated_at' => nil,
          'intent_to_file_benefits' => 'Survivors Pension and/or Dependency and Indemnity Compensation (DIC)' \
                                       ' (VA Form 21P-534 or VA Form 21P-534EZ)'
        }
      )
    end
  end

  describe '20_10206' do
    let(:data) do
      fixture_path = Rails.root.join(
        'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_20_10206.json'
      )
      JSON.parse(fixture_path.read)
    end
    let(:form_submission) { create(:form_submission, form_data: data.to_json, form_type: '20-10206') }
    let(:form_submission_attempt) { create(:form_submission_attempt, form_submission:) }

    it 'sends the confirmation email' do
      allow(VANotify::EmailJob).to receive(:perform_async)

      subject = described_class.new(form_submission_attempt:, notification_type: :confirmation)

      subject.send

      expect(VANotify::EmailJob).to have_received(:perform_async).with(
        'jv@example.com',
        'form20_10206_confirmation_email_template_id',
        {
          'first_name' => 'JOHN',
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
          'lighthouse_updated_at' => nil
        }
      )
    end
  end

  describe '20_10207' do
    context 'veteran' do
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_20_10207-veteran.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:form_submission) { create(:form_submission, form_data: data.to_json, form_type: '20-10207') }
      let(:form_submission_attempt) { create(:form_submission_attempt, form_submission:) }
      let(:user) { create(:user, :loa3) }

      it 'sends the confirmation email' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = described_class.new(form_submission_attempt:, notification_type: :confirmation, user:)

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          user.va_profile_email,
          'form20_10207_confirmation_email_template_id',
          {
            'first_name' => 'JOHN',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
            'lighthouse_updated_at' => nil
          }
        )
      end
    end

    context 'third-party-veteran' do
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_20_10207-third-party-veteran.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:form_submission) { create(:form_submission, form_data: data.to_json, form_type: '20-10207') }
      let(:form_submission_attempt) { create(:form_submission_attempt, form_submission:) }
      let(:user) { create(:user, :loa3) }

      it 'sends the confirmation email' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = described_class.new(form_submission_attempt:, notification_type: :confirmation, user:)

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          user.va_profile_email,
          'form20_10207_confirmation_email_template_id',
          {
            'first_name' => 'JOE',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
            'lighthouse_updated_at' => nil
          }
        )
      end
    end

    context 'non-veteran' do
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_20_10207-non-veteran.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:form_submission) { create(:form_submission, form_data: data.to_json, form_type: '20-10207') }
      let(:form_submission_attempt) { create(:form_submission_attempt, form_submission:) }
      let(:user) { create(:user, :loa3) }

      it 'sends the confirmation email' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = described_class.new(form_submission_attempt:, notification_type: :confirmation, user:)

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          user.va_profile_email,
          'form20_10207_confirmation_email_template_id',
          {
            'first_name' => 'JOHN',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
            'lighthouse_updated_at' => nil
          }
        )
      end
    end

    context 'third-party-non-veteran' do
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_20_10207-third-party-non-veteran.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:form_submission) { create(:form_submission, form_data: data.to_json, form_type: '20-10207') }
      let(:form_submission_attempt) { create(:form_submission_attempt, form_submission:) }
      let(:user) { create(:user, :loa3) }

      it 'sends the confirmation email' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = described_class.new(form_submission_attempt:, notification_type: :confirmation, user:)

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          user.va_profile_email,
          'form20_10207_confirmation_email_template_id',
          {
            'first_name' => 'JOE',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => form_submission_attempt.benefits_intake_uuid,
            'lighthouse_updated_at' => nil
          }
        )
      end
    end
  end
end
