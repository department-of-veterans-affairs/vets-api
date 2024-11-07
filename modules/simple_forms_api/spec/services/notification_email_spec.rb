# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::NotificationEmail do
  %i[confirmation error received].each do |notification_type|
    describe '#initialize' do
      context 'when all required arguments are passed in' do
        let(:config) do
          { form_data: {}, form_number: 'vba_21_10210', confirmation_number: 'confirmation_number',
            date_submitted: Time.zone.today.strftime('%B %d, %Y') }
        end

        it 'succeeds' do
          expect { described_class.new(config, notification_type:) }.not_to raise_error(ArgumentError)
        end
      end

      context 'missing form_data' do
        let(:config) do
          { form_number: 'vba_21_10210', confirmation_number: 'confirmation_number',
            date_submitted: Time.zone.today.strftime('%B %d, %Y') }
        end

        it 'fails' do
          expect { described_class.new(config, notification_type:) }.to raise_error(ArgumentError)
        end
      end

      context 'missing form_number' do
        let(:config) do
          { form_data: {}, confirmation_number: 'confirmation_number',
            date_submitted: Time.zone.today.strftime('%B %d, %Y') }
        end

        it 'fails' do
          expect { described_class.new(config, notification_type:) }.to raise_error(ArgumentError)
        end
      end

      context 'missing confirmation_number' do
        let(:config) do
          { form_data: {}, form_number: 'vba_21_10210', date_submitted: Time.zone.today.strftime('%B %d, %Y') }
        end

        it 'fails' do
          expect { described_class.new(config, notification_type:) }.to raise_error(ArgumentError)
        end
      end

      context 'missing date_submitted' do
        let(:config) do
          { form_data: {}, form_number: 'vba_21_10210', confirmation_number: 'confirmation_number' }
        end

        it 'fails' do
          expect { described_class.new(config, notification_type:) }.to raise_error(ArgumentError)
        end
      end
    end

    describe '#send' do
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_10210.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:config) do
        { form_data: data, form_number: 'vba_21_10210',
          confirmation_number: 'confirmation_number', date_submitted: }
      end

      context 'flipper is on' do
        before do
          allow(Flipper).to receive(:enabled?).and_return true
        end

        it 'sends the email' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          data['claim_ownership'] = 'self'
          data['claimant_type'] = 'veteran'

          subject = described_class.new(config, notification_type:)

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
          subject = described_class.new(config, notification_type:)

          subject.send

          expect(VANotify::EmailJob).not_to have_received(:perform_async)
        end
      end

      context 'send at time is specified' do
        context 'user_account is passed in' do
          let(:data) do
            fixture_path = Rails.root.join(
              'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_10210-min.json'
            )
            JSON.parse(fixture_path.read)
          end
          let(:user_account) { create(:user_account) }

          it 'sends the email at the specified time' do
            time = double
            profile = double(given_names: ['Bob'])
            mpi_profile = double(profile:, error: nil)
            allow(VANotify::UserAccountJob).to receive(:perform_at)
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(mpi_profile)
            subject = described_class.new(config, notification_type:, user_account:)

            subject.send(at: time)

            expect(VANotify::UserAccountJob).to have_received(:perform_at).with(time, user_account.id, anything,
                                                                                anything)
          end
        end

        context 'user and user_account are not passed in' do
          it 'sends the email at the specified time' do
            time = double
            allow(VANotify::EmailJob).to receive(:perform_at)
            subject = described_class.new(config, notification_type:)

            subject.send(at: time)

            expect(VANotify::EmailJob).to have_received(:perform_at).with(time, anything, anything, anything)
          end
        end
      end
    end

    describe '21_10210' do
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:config) do
        { form_data: data, form_number: 'vba_21_10210',
          confirmation_number: 'confirmation_number', date_submitted: }
      end

      context 'form data has an email address' do
        let(:data) do
          fixture_path = Rails.root.join(
            'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_10210.json'
          )
          JSON.parse(fixture_path.read)
        end

        context 'users own claim' do
          context 'is a veteran' do
            it 'calls VANotify::EmailJob' do
              allow(VANotify::EmailJob).to receive(:perform_async)
              data['claim_ownership'] = 'self'
              data['claimant_type'] = 'veteran'

              subject = described_class.new(config, notification_type:)

              subject.send

              expect(VANotify::EmailJob).to have_received(:perform_async).with(
                'veteran.longemail@email.com',
                "form21_10210_#{notification_type}_email_template_id",
                {
                  'first_name' => 'John',
                  'date_submitted' => date_submitted,
                  'confirmation_number' => 'confirmation_number',
                  'lighthouse_updated_at' => nil
                }
              )
            end
          end

          context 'is not a veteran' do
            it 'calls VANotify::EmailJob' do
              allow(VANotify::EmailJob).to receive(:perform_async)
              data['claim_ownership'] = 'self'
              data['claimant_type'] = 'non-veteran'

              subject = described_class.new(config, notification_type:)
              subject.send

              expect(VANotify::EmailJob).to have_received(:perform_async).with(
                'claimant.long@address.com',
                "form21_10210_#{notification_type}_email_template_id",
                {
                  'first_name' => 'Joe',
                  'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                  'confirmation_number' => 'confirmation_number',
                  'lighthouse_updated_at' => nil
                }
              )
            end
          end
        end

        context 'someone elses claim' do
          context 'claimant is a veteran' do
            it 'calls VANotify::EmailJob' do
              allow(VANotify::EmailJob).to receive(:perform_async)
              data['claim_ownership'] = 'third-party'
              data['claimant_type'] = 'veteran'

              subject = described_class.new(config, notification_type:)

              subject.send

              expect(VANotify::EmailJob).to have_received(:perform_async).with(
                'my.long.email.address@email.com',
                "form21_10210_#{notification_type}_email_template_id",
                {
                  'first_name' => 'Jack',
                  'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                  'confirmation_number' => 'confirmation_number',
                  'lighthouse_updated_at' => nil
                }
              )
            end
          end

          context 'claimant is not a veteran' do
            it 'calls VANotify::EmailJob' do
              allow(VANotify::EmailJob).to receive(:perform_async)
              data['claim_ownership'] = 'third-party'
              data['claimant_type'] = 'non-veteran'

              subject = described_class.new(config, notification_type:)

              subject.send

              expect(VANotify::EmailJob).to have_received(:perform_async).with(
                'my.long.email.address@email.com',
                "form21_10210_#{notification_type}_email_template_id",
                {
                  'first_name' => 'Jack',
                  'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                  'confirmation_number' => 'confirmation_number',
                  'lighthouse_updated_at' => nil
                }
              )
            end
          end
        end
      end

      context 'form data does not have an email address' do
        let(:data) do
          fixture_path = Rails.root.join(
            'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_10210-min.json'
          )
          JSON.parse(fixture_path.read)
        end

        context 'users own claim' do
          context 'is a veteran' do
            context 'user is passed in' do
              let(:user) { build(:user) }

              it 'calls VANotify::EmailJob with user record email' do
                allow(VANotify::EmailJob).to receive(:perform_async)
                data['claim_ownership'] = 'self'
                data['claimant_type'] = 'veteran'

                subject = described_class.new(config, notification_type:, user:)

                subject.send

                expect(VANotify::EmailJob).to have_received(:perform_async).with(
                  user.va_profile_email,
                  "form21_10210_#{notification_type}_email_template_id",
                  {
                    'first_name' => 'John',
                    'date_submitted' => date_submitted,
                    'confirmation_number' => 'confirmation_number',
                    'lighthouse_updated_at' => nil
                  }
                )
              end
            end

            context 'user is not passed in' do
              it 'does not call VANotify::EmailJob' do
                allow(VANotify::EmailJob).to receive(:perform_async)
                data['claim_ownership'] = 'self'
                data['claimant_type'] = 'veteran'

                subject = described_class.new(config, notification_type:)

                subject.send

                expect(VANotify::EmailJob).not_to have_received(:perform_async)
              end
            end
          end

          context 'is not a veteran' do
            context 'user is passed in' do
              let(:user) { build(:user) }

              it 'calls VANotify::EmailJob with user record email' do
                allow(VANotify::EmailJob).to receive(:perform_async)
                data['claim_ownership'] = 'self'
                data['claimant_type'] = 'non-veteran'
                data['claimant_full_name'] = { 'first' => 'Joe' }

                subject = described_class.new(config, notification_type:, user:)

                subject.send

                expect(VANotify::EmailJob).to have_received(:perform_async).with(
                  user.va_profile_email,
                  "form21_10210_#{notification_type}_email_template_id",
                  {
                    'first_name' => 'Joe',
                    'date_submitted' => date_submitted,
                    'confirmation_number' => 'confirmation_number',
                    'lighthouse_updated_at' => nil
                  }
                )
              end
            end

            context 'user is not passed in' do
              it 'does not call VANotify::EmailJob' do
                allow(VANotify::EmailJob).to receive(:perform_async)
                data['claim_ownership'] = 'self'
                data['claimant_type'] = 'non-veteran'

                subject = described_class.new(config, notification_type:)

                subject.send

                expect(VANotify::EmailJob).not_to have_received(:perform_async)
              end
            end
          end
        end
      end
    end

    describe '40_0247' do
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:config) do
        { form_data: data, form_number: 'vba_40_0247',
          confirmation_number: 'confirmation_number', date_submitted: }
      end

      context 'template_id is provided', if: notification_type == :confirmation do
        context 'when email is entered' do
          let(:data) do
            fixture_path = Rails.root.join(
              'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_40_0247.json'
            )
            JSON.parse(fixture_path.read)
          end

          it 'sends the confirmation email' do
            allow(VANotify::EmailJob).to receive(:perform_async)

            subject = described_class.new(config, notification_type:)

            subject.send

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              'a@b.com',
              'form40_0247_confirmation_email_template_id',
              {
                'first_name' => 'Joe',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
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

          context 'when user is signed in' do
            let(:user) { create(:user, :loa3) }

            it 'does not send the confirmation email' do
              allow(VANotify::EmailJob).to receive(:perform_async)
              expect(data['applicant_email']).to be_nil

              subject = described_class.new(config, notification_type:)

              subject.send

              expect(VANotify::EmailJob).not_to have_received(:perform_async)
            end
          end

          context 'when user is not signed in' do
            it 'does not send the confirmation email' do
              allow(VANotify::EmailJob).to receive(:perform_async)
              expect(data['applicant_email']).to be_nil

              subject = described_class.new(config)

              subject.send

              expect(VANotify::EmailJob).not_to have_received(:perform_async)
            end
          end
        end
      end

      context 'template_id is missing', if: notification_type == :received do
        let(:data) do
          fixture_path = Rails.root.join(
            'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_40_0247.json'
          )
          JSON.parse(fixture_path.read)
        end
        let(:user) { create(:user, :loa3) }

        it 'sends nothing' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          subject = described_class.new(config, notification_type:, user:)

          subject.send

          expect(VANotify::EmailJob).not_to have_received(:perform_async)
        end
      end
    end

    describe '40_10007 email' do
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:config) do
        { form_data: data, form_number: 'vba_40_10007',
          confirmation_number: 'confirmation_number', date_submitted: }
      end

      context 'template_id is provided', if: notification_type == :error do
        context 'when email is entered' do
          let(:data) do
            fixture_path = Rails.root.join(
              'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_40_10007.json'
            )
            JSON.parse(fixture_path.read)
          end
        end

        context 'when email is omitted' do
          let(:data) do
            fixture_path = Rails.root.join(
              'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_40_10007-min.json'
            )
            JSON.parse(fixture_path.read)
          end

          context 'when user is signed in' do
            let(:user) { create(:user, :loa3) }

            it 'does not send the confirmation email' do
              allow(VANotify::EmailJob).to receive(:perform_async)
              expect(data['application']['claimant']['email']).to be_nil

              subject = described_class.new(config, notification_type:)

              subject.send

              expect(VANotify::EmailJob).not_to have_received(:perform_async)
            end
          end

          context 'when user is not signed in' do
            it 'does not send the confirmation email' do
              allow(VANotify::EmailJob).to receive(:perform_async)
              expect(data['applicant_email']).to be_nil

              subject = described_class.new(config)

              subject.send

              expect(VANotify::EmailJob).not_to have_received(:perform_async)
            end
          end
        end
      end

      context 'template_id is missing', if: notification_type != :error do
        let(:data) do
          fixture_path = Rails.root.join(
            'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_40_10007.json'
          )
          JSON.parse(fixture_path.read)
        end
        let(:user) { create(:user, :loa3) }

        it 'sends nothing' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          subject = described_class.new(config, notification_type:, user:)

          subject.send

          expect(VANotify::EmailJob).not_to have_received(:perform_async)
        end
      end
    end

    describe '40-10007 first name' do
      subject { described_class.new(config) }

      let(:config) do
        {
          form_number: 'vba_40_10007',
          form_data: form_data,
          confirmation_number: '8679305',
          date_submitted: Time.zone.today.strftime('%B %d, %Y')
        }
      end

      context 'when the applicant is the claimant ("Self")' do
        let(:form_data) do
          {
            'application' => {
              'applicant' => {
                'applicant_relationship_to_claimant' => 'Self'
              },
              'claimant' => {
                'name' => {
                  'first' => 'Freddy'
                }
              },
              'veteran' => {
                'current_name' => {
                  'first' => 'Bob'
                }
              }
            }
          }
        end

        it 'returns the veteran first name' do
          expect(subject.instance_eval { form40_10007_first_name }).to eq('Freddy')
        end
      end

      context 'when the applicant is not the claimant' do
        let(:form_data) do
          {
            'application' => {
              'applicant' => {
                'applicant_relationship_to_claimant' => 'Authorized Agent/Rep',
                'name' => {
                  'first' => 'Jason'
                }
              },
              'claimant' => {
                'name' => {
                  'first' => 'Charles'
                }
              }
            }
          }
        end

        it 'returns the claimant first name' do
          expect(subject.instance_eval { form40_10007_first_name }).to eq('Jason')
        end
      end
    end

    describe '21_0845' do
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_0845.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:config) do
        { form_data: data, form_number: 'vba_21_0845', confirmation_number: 'confirmation_number', date_submitted: }
      end

      context 'form data has an email address' do
        describe 'signed in user' do
          let(:user) { create(:user) }

          it 'non-veteran authorizer' do
            allow(VANotify::EmailJob).to receive(:perform_async)
            data['authorizer_email'] = 'authorizer_email@example.com'

            subject = described_class.new(config, user:)

            subject.send

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              'authorizer_email@example.com',
              'form21_0845_confirmation_email_template_id',
              {
                'first_name' => 'Jack',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => nil
              }
            )
          end

          it 'veteran authorizer' do
            allow(VANotify::EmailJob).to receive(:perform_async)
            data['authorizer_type'] = 'veteran'
            data['authorizer_email'] = 'authorizer_email@example.com'

            subject = described_class.new(config, user: create(:user))

            subject.send

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              'authorizer_email@example.com',
              'form21_0845_confirmation_email_template_id',
              {
                'first_name' => 'John',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
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

            subject = described_class.new(config)

            subject.send

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              'authorizer_email@example.com',
              'form21_0845_confirmation_email_template_id',
              {
                'first_name' => 'Jack',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => nil
              }
            )
          end

          it 'veteran authorizer' do
            allow(VANotify::EmailJob).to receive(:perform_async)
            # form does not require email
            data['authorizer_type'] = 'veteran'

            subject = described_class.new(config)

            subject.send

            expect(VANotify::EmailJob).not_to have_received(:perform_async)
          end
        end
      end

      context 'form data does not have an email address' do
        describe 'signed in user' do
          let(:user) { create(:user) }

          it 'sends an email with VANotify::EmailJob' do
            allow(VANotify::EmailJob).to receive(:perform_async)

            subject = described_class.new(config, user:)

            subject.send

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              user.va_profile_email,
              'form21_0845_confirmation_email_template_id',
              {
                'first_name' => 'Jack',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => nil
              }
            )
          end
        end

        describe 'not signed in user' do
          it 'does not send an email' do
            allow(VANotify::EmailJob).to receive(:perform_async)

            subject = described_class.new(config)

            subject.send

            expect(VANotify::EmailJob).not_to have_received(:perform_async)
          end
        end
      end
    end

    describe '21_0966' do
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_0966.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:config) do
        { form_data: data, form_number: 'vba_21_0966',
          confirmation_number: 'confirmation_number', date_submitted: }
      end
      let(:user) { create(:user, :loa3) }

      context 'template_id is provided', unless: notification_type == :received do
        it 'sends the email' do
          allow(VANotify::EmailJob).to receive(:perform_async)

          subject = described_class.new(config, notification_type:, user:)

          subject.send

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            user.va_profile_email,
            "form21_0966_#{notification_type}_email_template_id",
            {
              'first_name' => 'Veteran',
              'date_submitted' => date_submitted,
              'confirmation_number' => 'confirmation_number',
              'lighthouse_updated_at' => nil,
              'intent_to_file_benefits' => 'Survivors Pension and/or Dependency and Indemnity Compensation (DIC)' \
                                           ' (VA Form 21P-534 or VA Form 21P-534EZ)'
            }
          )
        end

        context 'preparer is surviving dependent' do
          before do
            data['preparer_identification'] = 'SURVIVING_DEPENDENT'
            config[:form_data] = data
          end

          it 'sends the email' do
            allow(VANotify::EmailJob).to receive(:perform_async)

            subject = described_class.new(config, notification_type:, user:)

            subject.send

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              'survivor@dependent.com',
              "form21_0966_#{notification_type}_email_template_id",
              {
                'first_name' => 'I',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => nil,
                'intent_to_file_benefits' => 'Survivors Pension and/or Dependency and Indemnity Compensation (DIC)' \
                                             ' (VA Form 21P-534 or VA Form 21P-534EZ)'
              }
            )
          end
        end
      end

      context 'template_id is missing', if: notification_type == :received do
        let(:data) do
          fixture_path = Rails.root.join(
            'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_0966.json'
          )
          JSON.parse(fixture_path.read)
        end

        it 'sends nothing' do
          allow(VANotify::EmailJob).to receive(:perform_async)
          subject = described_class.new(config, notification_type:, user:)

          subject.send

          expect(VANotify::EmailJob).not_to have_received(:perform_async)
        end
      end
    end

    describe '20_10206' do
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_20_10206.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:config) do
        { form_data: data, form_number: 'vba_20_10206',
          confirmation_number: 'confirmation_number', date_submitted: }
      end

      it 'sends the confirmation email' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = described_class.new(config)

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'jv@example.com',
          'form20_10206_confirmation_email_template_id',
          {
            'first_name' => 'John',
            'date_submitted' => date_submitted,
            'confirmation_number' => 'confirmation_number',
            'lighthouse_updated_at' => nil
          }
        )
      end
    end

    describe '20_10207' do
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:config) do
        { form_data: data, form_number: 'vba_20_10207',
          confirmation_number: 'confirmation_number', date_submitted: }
      end

      context 'veteran' do
        let(:data) do
          fixture_path = Rails.root.join(
            'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_20_10207-veteran.json'
          )
          JSON.parse(fixture_path.read)
        end
        let(:user) { create(:user, :loa3) }

        it 'sends the confirmation email' do
          allow(VANotify::EmailJob).to receive(:perform_async)

          subject = described_class.new(config, user:)

          subject.send

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            user.va_profile_email,
            'form20_10207_confirmation_email_template_id',
            {
              'first_name' => 'John',
              'date_submitted' => date_submitted,
              'confirmation_number' => 'confirmation_number',
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
        let(:user) { create(:user, :loa3) }

        it 'sends the confirmation email' do
          allow(VANotify::EmailJob).to receive(:perform_async)

          subject = described_class.new(config, user:)

          subject.send

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            user.va_profile_email,
            'form20_10207_confirmation_email_template_id',
            {
              'first_name' => 'Joey Jo',
              'date_submitted' => date_submitted,
              'confirmation_number' => 'confirmation_number',
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
        let(:user) { create(:user, :loa3) }

        it 'sends the confirmation email' do
          allow(VANotify::EmailJob).to receive(:perform_async)

          subject = described_class.new(config, user:)

          subject.send

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            user.va_profile_email,
            'form20_10207_confirmation_email_template_id',
            {
              'first_name' => 'John',
              'date_submitted' => date_submitted,
              'confirmation_number' => 'confirmation_number',
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
        let(:user) { create(:user, :loa3) }

        it 'sends the confirmation email' do
          allow(VANotify::EmailJob).to receive(:perform_async)

          subject = described_class.new(config, user:)

          subject.send

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            user.va_profile_email,
            'form20_10207_confirmation_email_template_id',
            {
              'first_name' => 'Joe',
              'date_submitted' => date_submitted,
              'confirmation_number' => 'confirmation_number',
              'lighthouse_updated_at' => nil
            }
          )
        end
      end
    end
  end
end
