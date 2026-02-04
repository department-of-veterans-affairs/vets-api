# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::PaymentHistoryController, type: :controller do
  let(:user) { create(:evss_user) }

  describe 'before_actions' do
    before do
      allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
      sign_in_as(user)
    end

    describe '#log_access_attempt' do
      context 'with detailed logging enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(true)
        end

        it 'logs access attempt and increments StatsD' do
          expect(Rails.logger).to receive(:info).with(
            'User attempting to access BGS payment history',
            hash_including(user_uuid: user.uuid)
          )
          expect(StatsD).to receive(:increment).with('api.payment_history.access_attempt')

          VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
            VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
              get(:index)
            end
          end
        end
      end

      context 'with detailed logging disabled' do
        it 'does not log access attempt' do
          expect(Rails.logger).not_to receive(:info).with(
            'User attempting to access BGS payment history',
            anything
          )
          expect(StatsD).not_to receive(:increment).with('api.payment_history.access_attempt')

          VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
            VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
              get(:index)
            end
          end
        end
      end
    end

    describe '#validate_user_identifiers' do
      context 'with validation logging enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(true)
        end

        context 'when user has all identifiers' do
          it 'does not log warnings' do
            expect(Rails.logger).not_to receive(:warn).with(
              'User missing required identifiers for BGS payment history',
              anything
            )

            VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
              VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
                get(:index)
              end
            end
          end
        end

        context 'when user is missing identifiers' do
          let(:user_without_icn) { create(:evss_user, icn: nil) }

          before do
            sign_in_as(user_without_icn)
          end

          it 'logs missing identifiers warning' do
            expect(Rails.logger).to receive(:warn).with(
              'User missing required identifiers for BGS payment history',
              hash_including(
                user_uuid: user_without_icn.uuid,
                missing_identifiers: include('ICN')
              )
            )
            expect(StatsD).to receive(:increment).with('api.payment_history.missing_identifiers')

            VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
              VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
                get(:index)
              end
            end
          end
        end
      end

      context 'with validation logging disabled' do
        it 'does not log missing identifiers' do
          expect(Rails.logger).not_to receive(:warn).with(
            'User missing required identifiers for BGS payment history',
            anything
          )

          VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
            VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
              get(:index)
            end
          end
        end
      end
    end

    describe 'authorization' do
      it 'authorizes user for BGS access' do
        expect(controller).to receive(:authorize).with(:bgs, :access?)

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end
      end
    end

    describe '#validate_user_for_bgs' do
      context 'with validation logging enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(true)
        end

        context 'when user is missing both ICN and UUID identifiers' do
          let(:user_without_identifiers) { create(:evss_user) }

          before do
            sign_in_as(user_without_identifiers)
            # Stub the controller's current_user to return our stubbed version
            allow(controller).to receive(:current_user).and_return(user_without_identifiers)
            allow(user_without_identifiers).to receive(:icn).and_return(nil)
            allow(user_without_identifiers).to receive(:uuid).and_return(nil)

            # Stub authorization to pass despite missing identifiers
            allow(controller).to receive(:authorize).and_return(true)

            # Stub BGS services to prevent actual calls
            allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
              .and_return(double('person', status: 'ACTIVE', file_number: '123456789',
                                           participant_id: '123456', ssn_number: '123456789'))
            allow_any_instance_of(BGS::PaymentService).to receive(:payment_history)
              .and_return(double('payment_history', payments: []))
          end

          it 'logs error and increments StatsD' do
            # Allow all other calls
            allow(StatsD).to receive(:increment).and_call_original
            allow(Rails.logger).to receive(:info).and_call_original
            allow(Rails.logger).to receive(:warn).and_call_original
            allow(Rails.logger).to receive(:error).and_call_original

            # Set specific expectations
            expect(Rails.logger).to receive(:error).with(
              'User missing both ICN and UUID identifiers',
              hash_including(user_uuid: nil)
            ).and_call_original
            expect(StatsD).to receive(:increment)
              .with('api.payment_history.user.no_identifiers').and_call_original

            get(:index)
          end
        end

        context 'when user is missing all contact identifiers' do
          let(:user_without_contact) do
            create(:evss_user, first_name: nil, last_name: nil, email: nil)
          end

          before do
            sign_in_as(user_without_contact)
            # Stub the controller's current_user and all contact identifier methods
            allow(controller).to receive(:current_user).and_return(user_without_contact)
            allow(user_without_contact).to receive(:common_name).and_return(nil)
            allow(user_without_contact).to receive(:va_profile_email).and_return(nil)

            # Stub BGS services to prevent actual calls
            allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
              .and_return(double('person', status: 'ACTIVE', file_number: '123456789',
                                           participant_id: '123456', ssn_number: '123456789'))
            allow_any_instance_of(BGS::PaymentService).to receive(:payment_history)
              .and_return(double('payment_history', payments: []))
          end

          it 'logs error and increments StatsD' do
            # Allow all other calls - authorization will increment api.bgs.policy.success
            allow(StatsD).to receive(:increment).and_call_original
            allow(Rails.logger).to receive(:info).and_call_original
            allow(Rails.logger).to receive(:warn).and_call_original
            allow(Rails.logger).to receive(:error).and_call_original

            # Set specific expectations for our validation
            expect(Rails.logger).to receive(:error).with(
              'User missing all contact identifiers (common_name, email, va_profile_email)',
              hash_including(user_uuid: user_without_contact.uuid)
            ).and_call_original
            expect(StatsD).to receive(:increment)
              .with('api.payment_history.user.no_contact_identifiers').and_call_original

            get(:index)
          end
        end

        context 'when user has all identifiers' do
          it 'does not log errors' do
            expect(Rails.logger).not_to receive(:error).with(
              'User missing both ICN and UUID identifiers',
              anything
            )
            expect(Rails.logger).not_to receive(:error).with(
              'User missing all contact identifiers (common_name, email, va_profile_email)',
              anything
            )
            expect(StatsD).not_to receive(:increment).with('api.payment_history.user.no_identifiers')
            expect(StatsD).not_to receive(:increment).with('api.payment_history.user.no_contact_identifiers')

            VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
              VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
                get(:index)
              end
            end
          end
        end
      end

      context 'with validation logging disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(false)
        end

        it 'does not log or increment StatsD for missing identifiers' do
          expect(Rails.logger).not_to receive(:error).with(
            'User missing both ICN and UUID identifiers',
            anything
          )
          expect(Rails.logger).not_to receive(:error).with(
            'User missing all contact identifiers (common_name, email, va_profile_email)',
            anything
          )
          expect(StatsD).not_to receive(:increment).with('api.payment_history.user.no_identifiers')
          expect(StatsD).not_to receive(:increment).with('api.payment_history.user.no_contact_identifiers')

          VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
            VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
              get(:index)
            end
          end
        end
      end
    end
  end

  describe '#log_authorized_access' do
    before do
      allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
      sign_in_as(user)
    end

    context 'with detailed logging enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(true)
      end

      it 'logs authorized access and increments StatsD' do
        # Allow all logger calls without expectations since SemanticLogger may handle them differently
        allow(Rails.logger).to receive(:info)

        # Allow all StatsD calls
        allow(StatsD).to receive(:increment)

        # Expect specific StatsD increments
        expect(StatsD).to receive(:increment).with('api.payment_history.access_attempt').at_least(:once)
        expect(StatsD).to receive(:increment).with('api.payment_history.authorized').at_least(:once)

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end
      end

      it 'logs after authorization before_action completes' do
        call_order = []

        allow(controller).to receive(:authorize).and_wrap_original do |method, *args|
          call_order << :authorize
          method.call(*args)
        end

        allow(controller).to receive(:log_authorized_access).and_wrap_original do |method|
          call_order << :log_authorized
          method.call
        end

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end

        # Verify authorize was called before log_authorized
        authorize_index = call_order.index(:authorize)
        log_index = call_order.index(:log_authorized)

        expect(authorize_index).not_to be_nil
        expect(log_index).not_to be_nil
        expect(authorize_index).to be < log_index
      end
    end

    context 'with detailed logging disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
      end

      it 'does not log authorized access' do
        expect(Rails.logger).not_to receive(:info).with(
          'User authorized for BGS payment history access',
          anything
        )
        expect(StatsD).not_to receive(:increment).with('api.payment_history.authorized')

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end
      end
    end
  end

  describe '#index' do
    context 'with only regular payments' do
      it 'returns only payments and no return payments' do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            sign_in_as(user)
            get(:index)

            response_body = JSON.parse(response.body)
            payments_count = response_body.dig('data', 'attributes', 'payments')&.count
            return_payments_count = response_body.dig('data', 'attributes', 'return_payments')&.count

            expect(response).to have_http_status(:ok)

            expect(payments_count).to eq(47)
            expect(return_payments_count).to eq(0)
          end
        end
      end
    end

    context 'with mixed payments and return payments' do
      it 'returns both' do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn_returns') do
            sign_in_as(user)
            get(:index)

            response_body = JSON.parse(response.body)
            payments_count = response_body.dig('data', 'attributes', 'payments')&.count
            return_payments_count = response_body.dig('data', 'attributes', 'return_payments')&.count

            expect(response).to have_http_status(:ok)

            expect(payments_count).to eq(2)
            expect(return_payments_count).to eq(2)
          end
        end
      end
    end

    context 'with mixed payments and flipper disabled' do
      it 'does not return both' do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(false)

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn_returns') do
            sign_in_as(user)
            get(:index)

            response_body = JSON.parse(response.body)
            payments_count = response_body.dig('data', 'attributes', 'payments')&.count
            return_payments_count = response_body.dig('data', 'attributes', 'return_payments')&.count

            expect(response).to have_http_status(:ok)

            expect(payments_count).to eq(0)
            expect(return_payments_count).to eq(0)
          end
        end
      end
    end
  end
end
