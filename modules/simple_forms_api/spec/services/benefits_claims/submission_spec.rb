# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe SimpleFormsApi::BenefitsClaims::Submission do
  forms = described_class::INTENT_API_FORMS

  describe '#submit' do
    shared_context 'form submission' do |form_id|
      context "for form #{form_id}" do
        subject(:submit) { instance.submit }

        let(:fixture_path) { %w[modules simple_forms_api spec fixtures] }
        let(:notification_email_double) { instance_double(SimpleFormsApi::NotificationEmail) }
        let(:intent_service_double) { instance_double(SimpleFormsApi::IntentToFile) }
        let(:form_name) { "vba_#{form_id.gsub('-', '_')}" }
        let(:form_class) { "SimpleFormsApi::#{form_name.titleize.delete(' ')}".constantize }
        let(:form_json_path) { Rails.root.join(*fixture_path, 'form_json', "#{form_name}.json") }
        let(:params) { JSON.parse(form_json_path.read) }
        let(:current_user) { build(:user, :loa3) }
        let(:instance) { described_class.new(current_user, params) }

        let(:confirmation_number) { '123456' }
        let(:expiration_date) { '2021-12-31' }
        let(:mock_intent_response) { [confirmation_number, expiration_date] }
        let(:notification_response) { true }
        let(:email_flag_enabled?) { true }
        let(:mock_intents) do
          {
            'compensation' => { 'data' => { 'id' => '123', 'attributes' => { 'expirationDate' => '2021-12-31' } } },
            'pension' => { 'data' => { 'id' => '234', 'attributes' => { 'expirationDate' => '2021-12-31' } } },
            'survivor' => { 'data' => { 'id' => '345', 'attributes' => { 'expirationDate' => '2021-12-31' } } }
          }
        end

        before do
          allow(form_class).to receive(:new).and_call_original
          allow(SimpleFormsApi::IntentToFile).to receive(:new).and_return(intent_service_double)
          allow(intent_service_double).to receive_messages(submit: mock_intent_response, existing_intents: mock_intents)
          allow(SimpleFormsApi::NotificationEmail).to receive(:new).and_return(notification_email_double)
          allow(notification_email_double).to receive(:send).and_return(notification_response)
          allow(Flipper).to receive(:enabled?).with(:simple_forms_email_confirmations).and_return(email_flag_enabled?)
          allow(Rails.logger).to receive(:info)
          allow(Rails.logger).to receive(:error)
          allow(SimpleFormsApi::BenefitsIntake::Submission).to receive(:new).and_call_original
          submit
        end

        it 'creates a new instance of the form class' do
          expect(form_class).to have_received(:new).with(params)
        end

        it 'calls intent service submit method' do
          expect(intent_service_double).to have_received(:submit)
        end

        it "logs the form's submission" do
          expect(Rails.logger).to have_received(:info).with(
            'Simple forms api - 21-0966 submission user identity',
            {
              benefit_types: 'survivor',
              confirmation_number: '123456',
              identity: 'THIRD_PARTY_SURVIVING_DEPENDENT'
            }
          )
        end

        context 'when simple_forms_email_confirmations is enabled' do
          let(:email_flag_enabled?) { true }

          it 'sends a notification email' do
            expect(SimpleFormsApi::NotificationEmail).to(
              have_received(:new).with(
                a_hash_including(form_number: "#{form_name}_intent_api"),
                a_hash_including(notification_type: :received)
              )
            )
            expect(notification_email_double).to have_received(:send)
          end

          it 'returns a hash with accurate data' do
            expect(submit).to eq(
              json: {
                confirmation_number:,
                expiration_date:,
                compensation_intent: mock_intents['compensation'],
                pension_intent: mock_intents['pension'],
                survivor_intent: mock_intents['survivor']
              }
            )
          end
        end

        context 'when simple_forms_email_confirmations is not enabled' do
          let(:email_flag_enabled?) { false }

          it 'returns a hash with accurate data' do
            expect(submit).to eq(
              json: {
                confirmation_number:,
                expiration_date:,
                compensation_intent: mock_intents['compensation'],
                pension_intent: mock_intents['pension'],
                survivor_intent: mock_intents['survivor']
              }
            )
          end
        end

        context 'when the intent service throws an error' do
          context 'when UnprocessableEntity is thrown' do
            before do
              allow(intent_service_double).to(
                receive(:submit).and_raise(Common::Exceptions::UnprocessableEntity, 'oopsy')
              )
            end

            it 'logs the error' do
              expect(Rails.logger).to have_received(:error)
            end

            it 'submits the form to the Benefits Intake API' do
              expect(SimpleFormsApi::BenefitsIntake::Submission).to have_received(:new).with(current_user, params)
            end
          end

          context 'when BenefitsClaimsApiDownError is thrown' do
            before do
              allow(intent_service_double).to(
                receive(:submit).and_raise(SimpleFormsApi::Exceptions::BenefitsClaimsApiDownError, 'oopsy')
              )
            end

            it 'logs the error' do
              expect(Rails.logger).to have_received(:error)
            end

            it 'submits the form to the Benefits Intake API' do
              expect(SimpleFormsApi::BenefitsIntake::Submission).to have_received(:new).with(current_user, params)
            end
          end
        end
      end
    end

    forms.each do |form_id|
      include_examples 'form submission', form_id
    end
  end
end
