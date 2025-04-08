# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

shared_examples 'an error notification email' do
  it 'increments StatsD' do
    allow(StatsD).to receive(:increment)

    expect { described_class.new(config, notification_type: :error) }.to raise_error(ArgumentError)
    expect(StatsD).to have_received(:increment).with('silent_failure', tags: anything)
  end
end

describe SimpleFormsApi::Notification::Email do
  let(:lighthouse_updated_at) { Time.current }

  %i[confirmation error received].each do |notification_type|
    describe '#initialize' do
      context 'when all required arguments are passed in' do
        let(:config) do
          { form_data: {}, form_number: 'vba_21_10210', confirmation_number: 'confirmation_number',
            date_submitted: Time.zone.today.strftime('%B %d, %Y') }
        end

        it 'succeeds' do
          expect { described_class.new(config, notification_type:) }.not_to raise_error
        end
      end

      context '26-4555' do
        let(:config) do
          { form_data: {}, form_number: 'vba_26_4555', date_submitted: Time.zone.today.strftime('%B %d, %Y') }
        end

        context 'notification_type is duplicate' do
          it 'does not require the confirmation_number' do
            expect { described_class.new(config, notification_type: :duplicate) }.not_to raise_error
          end
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

        it_behaves_like 'an error notification email' if notification_type == :error
      end

      context 'missing form_number' do
        let(:config) do
          { form_data: {}, confirmation_number: 'confirmation_number',
            date_submitted: Time.zone.today.strftime('%B %d, %Y') }
        end

        it 'fails' do
          expect { described_class.new(config, notification_type:) }.to raise_error(ArgumentError)
        end

        it_behaves_like 'an error notification email' if notification_type == :error
      end

      context 'missing confirmation_number' do
        let(:config) do
          { form_data: {}, form_number: 'vba_21_10210', date_submitted: Time.zone.today.strftime('%B %d, %Y') }
        end

        it 'fails' do
          expect { described_class.new(config, notification_type:) }.to raise_error(ArgumentError)
        end

        it_behaves_like 'an error notification email' if notification_type == :error
      end

      context 'missing date_submitted' do
        let(:config) do
          { form_data: {}, form_number: 'vba_21_10210', confirmation_number: 'confirmation_number' }
        end

        it 'fails' do
          expect { described_class.new(config, notification_type:) }.to raise_error(ArgumentError)
        end

        it_behaves_like 'an error notification email' if notification_type == :error
      end

      context 'form not supported' do
        let(:config) do
          { form_data: {}, form_number: 'nonsense', confirmation_number: 'confirmation_number',
            date_submitted: Time.zone.today.strftime('%B %d, %Y') }
        end

        it 'fails' do
          expect { described_class.new(config, notification_type:) }.to raise_error(ArgumentError)
        end

        it_behaves_like 'an error notification email' if notification_type == :error
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
          confirmation_number: 'confirmation_number', date_submitted:, lighthouse_updated_at: }
      end

      context 'flipper is on' do
        before do
          allow(Flipper).to receive(:enabled?).and_return true
        end

        context 'fetching the template id' do
          let(:template_id_suffix) { 'template_id_suffix' }
          let(:template_id) { 'abc-123' }
          let(:vanotify_settings) { double }
          let(:vanotify_services) { double }
          let(:va_gov) { double }

          before do
            stub_const(
              'SimpleFormsApi::Notification::Email::TEMPLATE_IDS',
              { 'vba_21_10210' => {
                'confirmation' => template_id_suffix,
                'error' => template_id_suffix,
                'received' => template_id_suffix
              } }
            )
            allow(Settings).to receive(:vanotify).and_return(vanotify_settings)
            allow(vanotify_settings).to receive(:services).and_return(vanotify_services)
            allow(vanotify_services).to receive(:va_gov).and_return(va_gov)
            allow(va_gov).to receive(:template_id).and_return({ template_id_suffix => template_id })
          end

          it 'gets the correct template id' do
            allow(VANotify::EmailJob).to receive(:perform_async)
            subject = described_class.new(config, notification_type:)

            subject.send

            expect(VANotify::EmailJob).to have_received(:perform_async).with(anything, template_id, anything)
          end
        end

        context 'success' do
          let(:email_job_id) { 'abc-123' }

          before do
            allow(VANotify::EmailJob).to receive(:perform_async).and_return(email_job_id)
            data['claim_ownership'] = 'self'
            data['claimant_type'] = 'veteran'
          end

          it 'sends the email' do
            subject = described_class.new(config, notification_type:)

            subject.send

            expect(VANotify::EmailJob).to have_received(:perform_async)
          end

          it 'logs the email_job_id' do
            allow(Rails.logger).to receive(:info)

            subject = described_class.new(config, notification_type:)

            subject.send

            expect(Rails.logger).to have_received(:info).with(
              'Simple Forms - Email job enqueued',
              email_job_id:,
              confirmation_number: anything
            )
          end
        end

        context 'failure' do
          let(:profile) { double(given_names: []) }
          let(:mpi_profile) { double(profile:, error: nil) }

          before do
            allow(VANotify::EmailJob).to receive(:perform_async)
            allow(VANotify::UserAccountJob).to receive(:perform_at)
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(mpi_profile)
            allow(StatsD).to receive(:increment)
            allow(Rails.logger).to receive(:error)
            data['witness_full_name']['first'] = nil
          end

          context 'error notification', if: notification_type == :error do
            it 'increments StatsD' do
              subject = described_class.new(config, notification_type:)
              subject.send

              expect(VANotify::EmailJob).not_to have_received(:perform_async)
              expect(StatsD).to have_received(:increment).with('silent_failure', tags: anything)
            end

            it 'logs the failure' do
              subject = described_class.new(config, notification_type:)
              subject.send

              expect(VANotify::EmailJob).not_to have_received(:perform_async)
              expect(Rails.logger).to have_received(:error).with('Simple Forms - Error email job failed to enqueue',
                                                                 confirmation_number: anything)
            end
          end

          context 'non-error notification', if: notification_type != :error do
            it 'logs the failure' do
              subject = described_class.new(config, notification_type:)
              subject.send

              expect(VANotify::EmailJob).not_to have_received(:perform_async)
              expect(Rails.logger).to have_received(:error).with('Simple Forms - Non-error email job failed to enqueue',
                                                                 confirmation_number: anything)
            end
          end
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
          let(:confirmation_number) { 'confirmation_number' }
          let(:data) do
            fixture_path = Rails.root.join(
              'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_10210-min.json'
            )
            JSON.parse(fixture_path.read)
          end
          let(:user_account) { create(:user_account) }

          it 'sends the email at the specified time' do
            time = Time.zone.now
            profile = double(given_names: ['Bob'])
            mpi_profile = double(profile:, error: nil)
            allow(VANotify::UserAccountJob).to receive(:perform_at)
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(mpi_profile)
            subject = described_class.new(config, notification_type:, user_account:)

            subject.send(at: time)

            expect(VANotify::UserAccountJob).to have_received(:perform_at).with(
              time,
              user_account.id,
              "form21_10210_#{notification_type}_email_template_id",
              {
                'confirmation_number' => confirmation_number,
                'date_submitted' => time.strftime('%B %d, %Y'),
                'first_name' => 'Bob',
                'lighthouse_updated_at' => lighthouse_updated_at
              },
              'fake_secret',
              {
                callback_metadata: {
                  form_number: 'vba_21_10210',
                  notification_type:,
                  confirmation_number:,
                  statsd_tags: {
                    'function' => 'vba_21_10210 form submission to Lighthouse', 'service' => 'veteran-facing-forms'
                  }
                }
              }
            )
          end
        end

        context 'user and user_account are not passed in' do
          it 'sends the email at the specified time' do
            time = double
            allow(VANotify::EmailJob).to receive(:perform_at)
            subject = described_class.new(config, notification_type:)

            subject.send(at: time)

            expect(VANotify::EmailJob).to have_received(:perform_at).with(time, anything, anything, anything, anything,
                                                                          anything)
          end
        end
      end
    end

    describe '21_10210' do
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:config) do
        { form_data: data, form_number: 'vba_21_10210',
          confirmation_number: 'confirmation_number', date_submitted:, lighthouse_updated_at: }
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
                  'lighthouse_updated_at' => lighthouse_updated_at
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
                  'lighthouse_updated_at' => lighthouse_updated_at
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
                  'lighthouse_updated_at' => lighthouse_updated_at
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
                  'lighthouse_updated_at' => lighthouse_updated_at
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
                  user.email,
                  "form21_10210_#{notification_type}_email_template_id",
                  {
                    'first_name' => 'John',
                    'date_submitted' => date_submitted,
                    'confirmation_number' => 'confirmation_number',
                    'lighthouse_updated_at' => lighthouse_updated_at
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
                  user.email,
                  "form21_10210_#{notification_type}_email_template_id",
                  {
                    'first_name' => 'Joe',
                    'date_submitted' => date_submitted,
                    'confirmation_number' => 'confirmation_number',
                    'lighthouse_updated_at' => lighthouse_updated_at
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
          confirmation_number: 'confirmation_number', date_submitted:, lighthouse_updated_at: }
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
                'lighthouse_updated_at' => lighthouse_updated_at
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

    describe '21_0845' do
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_0845.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:config) do
        { form_data: data, form_number: 'vba_21_0845', confirmation_number: 'confirmation_number', date_submitted:,
          lighthouse_updated_at: }
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
                'lighthouse_updated_at' => lighthouse_updated_at
              }
            )
          end

          it 'veteran authorizer' do
            allow(VANotify::EmailJob).to receive(:perform_async)
            data['authorizer_type'] = 'veteran'
            data['veteran_email'] = 'veteran_email@example.com'

            subject = described_class.new(config, user: create(:user))

            subject.send

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              'veteran_email@example.com',
              'form21_0845_confirmation_email_template_id',
              {
                'first_name' => 'John',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => lighthouse_updated_at
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
                'lighthouse_updated_at' => lighthouse_updated_at
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
              user.email,
              'form21_0845_confirmation_email_template_id',
              {
                'first_name' => 'Jack',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => lighthouse_updated_at
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
      let(:lighthouse_updated_at) { 1.day.ago }
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_0966.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:config) do
        { form_data: data, form_number: 'vba_21_0966',
          confirmation_number: 'confirmation_number', date_submitted:, lighthouse_updated_at: }
      end
      let(:user) { create(:user, :loa3) }

      it 'sends the email' do
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = described_class.new(config, notification_type:, user:)

        subject.send

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          user.email,
          "form21_0966_#{notification_type}_email_template_id",
          {
            'first_name' => 'Veteran',
            'date_submitted' => date_submitted,
            'confirmation_number' => 'confirmation_number',
            'lighthouse_updated_at' => lighthouse_updated_at,
            'intent_to_file_benefits' => 'survivors pension benefits',
            'intent_to_file_benefits_links' => '[Apply for DIC, Survivors Pension, and/or Accrued Benefits ' \
                                               '(VA Form 21P-534EZ)](https://www.va.gov/find-forms/about-form-21p-534ez/)',
            'itf_api_expiration_date' => nil
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
              'lighthouse_updated_at' => lighthouse_updated_at,
              'intent_to_file_benefits' => 'survivors pension benefits',
              'intent_to_file_benefits_links' => '[Apply for DIC, Survivors Pension, and/or Accrued Benefits ' \
                                                 '(VA Form 21P-534EZ)](https://www.va.gov/find-forms/about-form-21p-534ez/)',
              'itf_api_expiration_date' => nil
            }
          )
        end
      end
    end

    describe '21_0966 through Intent to File API', if: notification_type == :received do
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:expiration_date) { 1.year.from_now.strftime('%B %d, %Y') }
      let(:data) do
        fixture_path = Rails.root.join(
          'modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', 'vba_21_0966.json'
        )
        JSON.parse(fixture_path.read)
      end
      let(:user) { create(:user, :loa3) }

      context 'template_id is provided' do
        context 'expiration_date is provided' do
          let(:config) do
            { form_data: data, form_number: 'vba_21_0966_intent_api',
              confirmation_number: 'confirmation_number', date_submitted:, expiration_date: }
          end

          it 'sends the email' do
            allow(VANotify::EmailJob).to receive(:perform_async)

            subject = described_class.new(config, notification_type:, user:)

            subject.send

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              user.email,
              'form21_0966_itf_api_received_email_template_id',
              {
                'first_name' => 'Veteran',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'intent_to_file_benefits' => 'survivors pension benefits',
                'intent_to_file_benefits_links' => '[Apply for DIC, Survivors Pension, and/or Accrued Benefits ' \
                                                   '(VA Form 21P-534EZ)](https://www.va.gov/find-forms/about-form-21p-534ez/)',
                'itf_api_expiration_date' => expiration_date
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
                'form21_0966_itf_api_received_email_template_id',
                {
                  'first_name' => 'I',
                  'date_submitted' => date_submitted,
                  'confirmation_number' => 'confirmation_number',
                  'intent_to_file_benefits' => 'survivors pension benefits',
                  'intent_to_file_benefits_links' => '[Apply for DIC, Survivors Pension, and/or Accrued Benefits ' \
                                                     '(VA Form 21P-534EZ)](https://www.va.gov/find-forms/about-form-21p-534ez/)',
                  'itf_api_expiration_date' => expiration_date
                }
              )
            end
          end
        end

        context 'expiration_date is missing' do
          let(:config) do
            { form_data: data, form_number: 'vba_21_0966_intent_api',
              confirmation_number: 'confirmation_number', date_submitted: }
          end

          it 'raises ArgumentError' do
            expect { described_class.new(config, notification_type:, user:) }.to raise_error(ArgumentError)
          end
        end
      end

      context 'template_id is missing', unless: notification_type == :received do
        let(:config) do
          { form_data: data, form_number: 'vba_21_0966_intent_api',
            confirmation_number: 'confirmation_number', date_submitted:, expiration_date: }
        end

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
          confirmation_number: 'confirmation_number', date_submitted:, lighthouse_updated_at: }
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
            'lighthouse_updated_at' => lighthouse_updated_at
          }
        )
      end
    end

    describe '20_10207' do
      subject(:send_email) { described_class.new(config, user:).send }

      let(:data_path) { %w[modules simple_forms_api spec fixtures form_json] }
      let(:fixture_path) { Rails.root.join(*data_path, data_file) }
      let(:data) { JSON.parse(fixture_path.read) }
      let(:user) { create(:user, :loa3) }
      let(:date_submitted) { Time.zone.today.strftime('%B %d, %Y') }
      let(:config) do
        {
          form_data: data,
          form_number: 'vba_20_10207',
          confirmation_number: 'confirmation_number',
          date_submitted:,
          lighthouse_updated_at:
        }
      end

      before { allow(VANotify::EmailJob).to receive(:perform_async) }

      context 'veteran' do
        let(:data_file) { 'vba_20_10207-veteran.json' }

        context('when the email is provided') do
          it 'sends the confirmation email' do
            send_email

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              data['veteran_email_address'],
              'form20_10207_confirmation_email_template_id',
              {
                'first_name' => 'John',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => lighthouse_updated_at
              }
            )
          end
        end

        context('when the email is not provided') do
          before { data['veteran_email_address'] = nil }

          it 'sends the confirmation email' do
            send_email

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              user.email,
              'form20_10207_confirmation_email_template_id',
              {
                'first_name' => 'John',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => lighthouse_updated_at
              }
            )
          end
        end
      end

      context 'third-party-veteran' do
        let(:data_file) { 'vba_20_10207-third-party-veteran.json' }

        context('when the email is provided') do
          it 'sends the confirmation email' do
            send_email

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              data['third_party_email_address'],
              'form20_10207_confirmation_email_template_id',
              {
                'first_name' => 'Joey Jo',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => lighthouse_updated_at
              }
            )
          end
        end

        context('when the email is not provided') do
          before { data['third_party_email_address'] = nil }

          it 'sends the confirmation email' do
            send_email

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              user.email,
              'form20_10207_confirmation_email_template_id',
              {
                'first_name' => 'Joey Jo',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => lighthouse_updated_at
              }
            )
          end
        end
      end

      context 'non-veteran' do
        let(:data_file) { 'vba_20_10207-non-veteran.json' }

        context('when the email is provided') do
          it 'sends the confirmation email' do
            send_email

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              data['non_veteran_email_address'],
              'form20_10207_confirmation_email_template_id',
              {
                'first_name' => 'John',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => lighthouse_updated_at
              }
            )
          end
        end

        context('when the email is not provided') do
          before { data['non_veteran_email_address'] = nil }

          it 'sends the confirmation email' do
            send_email

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              user.email,
              'form20_10207_confirmation_email_template_id',
              {
                'first_name' => 'John',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => lighthouse_updated_at
              }
            )
          end
        end
      end

      context 'third-party-non-veteran' do
        let(:data_file) { 'vba_20_10207-third-party-non-veteran.json' }

        context('when the email is provided') do
          it 'sends the confirmation email' do
            send_email

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              data['third_party_email_address'],
              'form20_10207_confirmation_email_template_id',
              {
                'first_name' => 'Joe',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => lighthouse_updated_at
              }
            )
          end
        end

        context('when the email is not provided') do
          before { data['third_party_email_address'] = nil }

          it 'sends the confirmation email' do
            send_email

            expect(VANotify::EmailJob).to have_received(:perform_async).with(
              user.email,
              'form20_10207_confirmation_email_template_id',
              {
                'first_name' => 'Joe',
                'date_submitted' => date_submitted,
                'confirmation_number' => 'confirmation_number',
                'lighthouse_updated_at' => lighthouse_updated_at
              }
            )
          end
        end
      end
    end
  end
end
