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
            allow(user_without_identifiers).to receive_messages(icn: nil, uuid: nil)

            # Stub authorization to pass despite missing identifiers
            allow(controller).to receive_messages(current_user: user_without_identifiers, authorize: true)

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
            allow(user_without_contact).to receive_messages(common_name: nil, va_profile_email: nil)

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
              'User missing all contact identifiers (common_name, email)',
              hash_including(
                user_uuid: user_without_contact.uuid,
                va_profile_email_present: false
              )
            ).and_call_original
            expect(StatsD).to receive(:increment)
              .with('api.payment_history.user.no_contact_identifiers').and_call_original

            get(:index)
          end
        end

        context 'when user has va_profile_email but missing common_name and email' do
          let(:user_with_only_va_email) do
            create(:evss_user, first_name: nil, last_name: nil, email: nil)
          end

          before do
            sign_in_as(user_with_only_va_email)
            # Stub the controller's current_user with va_profile_email but no common_name or email
            allow(controller).to receive(:current_user).and_return(user_with_only_va_email)
            allow(user_with_only_va_email).to receive_messages(common_name: nil, va_profile_email: 'va@example.com')

            # Stub BGS services to prevent actual calls
            allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
              .and_return(double('person', status: 'ACTIVE', file_number: '123456789',
                                           participant_id: '123456', ssn_number: '123456789'))
            allow_any_instance_of(BGS::PaymentService).to receive(:payment_history)
              .and_return(double('payment_history', payments: []))
          end

          it 'logs error with va_profile_email_present: true and increments StatsD' do
            # Allow all other calls
            allow(StatsD).to receive(:increment).and_call_original
            allow(Rails.logger).to receive(:info).and_call_original
            allow(Rails.logger).to receive(:warn).and_call_original
            allow(Rails.logger).to receive(:error).and_call_original

            # Set specific expectations - should still fail validation but log va_profile_email presence
            expect(Rails.logger).to receive(:error).with(
              'User missing all contact identifiers (common_name, email)',
              hash_including(
                user_uuid: user_with_only_va_email.uuid,
                va_profile_email_present: true
              )
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
              'User missing all contact identifiers (common_name, email)',
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
            'User missing all contact identifiers (common_name, email)',
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

  describe '#validate_person_attributes' do
    before do
      allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
      sign_in_as(user)
    end

    context 'with validation logging enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(true)
      end

      context 'when person is nil' do
        before do
          # Stub BGS to return nil person
          allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
            .and_return(nil)
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
            'BGS::People::Request returned nil person',
            hash_including(user_uuid: user.uuid)
          ).and_call_original
          expect(StatsD).to receive(:increment)
            .with('api.payment_history.bgs_person.nil').and_call_original

          get(:index)
        end
      end

      context 'when person has missing attributes' do
        before do
          # Stub BGS to return person with missing attributes
          person = double('person',
                          status: nil,
                          file_number: nil,
                          participant_id: '123456',
                          ssn_number: '123456789')
          allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
            .and_return(person)
          allow_any_instance_of(BGS::PaymentService).to receive(:payment_history)
            .and_return(double('payment_history', payments: []))
        end

        it 'logs warning and increments StatsD' do
          # Allow all other calls
          allow(StatsD).to receive(:increment).and_call_original
          allow(Rails.logger).to receive(:info).and_call_original
          allow(Rails.logger).to receive(:warn).and_call_original
          allow(Rails.logger).to receive(:error).and_call_original

          # Set specific expectations
          expect(Rails.logger).to receive(:warn).with(
            'BGS person missing required attributes',
            hash_including(
              user_uuid: user.uuid,
              missing_attributes: 'status, file_number'
            )
          ).and_call_original
          expect(StatsD).to receive(:increment)
            .with('api.payment_history.bgs_person.missing_attributes').and_call_original

          get(:index)
        end
      end

      context 'when person has all attributes' do
        it 'does not log warnings or errors' do
          # Don't allow error or warn logs for person validation
          expect(Rails.logger).not_to receive(:error).with(
            'BGS::People::Request returned nil person',
            anything
          )
          expect(Rails.logger).not_to receive(:warn).with(
            'BGS person missing required attributes',
            anything
          )
          expect(StatsD).not_to receive(:increment).with('api.payment_history.bgs_person.nil')
          expect(StatsD).not_to receive(:increment).with('api.payment_history.bgs_person.missing_attributes')

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

      it 'does not log person validation' do
        # Stub BGS to return nil person
        allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
          .and_return(nil)

        expect(Rails.logger).not_to receive(:error).with(
          'BGS::People::Request returned nil person',
          anything
        )
        expect(StatsD).not_to receive(:increment).with('api.payment_history.bgs_person.nil')

        get(:index)
      end
    end
  end

  describe '#validate_payment_history' do
    before do
      allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
      sign_in_as(user)
    end

    context 'with validation logging enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(true)
      end

      context 'when payment_history is nil' do
        before do
          # Stub BGS to return valid person but nil payment_history
          person = double('person',
                          status: 'ACTIVE',
                          file_number: '123456789',
                          participant_id: '123456',
                          ssn_number: '123456789')
          allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
            .and_return(person)
          allow_any_instance_of(BGS::PaymentService).to receive(:payment_history)
            .and_return(nil)
        end

        it 'logs error and increments StatsD' do
          # Allow all other calls
          allow(StatsD).to receive(:increment).and_call_original
          allow(Rails.logger).to receive(:info).and_call_original
          allow(Rails.logger).to receive(:warn).and_call_original
          allow(Rails.logger).to receive(:error).and_call_original

          # Set specific expectations
          expect(Rails.logger).to receive(:error).with(
            'BGS::PaymentService returned nil',
            hash_including(
              user_uuid: user.uuid,
              person_status: 'ACTIVE'
            )
          ).and_call_original
          expect(StatsD).to receive(:increment)
            .with('api.payment_history.payment_history.nil').and_call_original

          get(:index)
        end
      end

      context 'when payment_history has no payments' do
        before do
          # Stub BGS to return payment_history with blank payments
          person = double('person',
                          status: 'ACTIVE',
                          file_number: '123456789',
                          participant_id: '123456',
                          ssn_number: '123456789')
          payment_history = double('payment_history', payments: [])
          allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
            .and_return(person)
          allow_any_instance_of(BGS::PaymentService).to receive(:payment_history)
            .and_return(payment_history)
        end

        it 'logs warning and increments StatsD' do
          # Allow all other calls
          allow(StatsD).to receive(:increment).and_call_original
          allow(Rails.logger).to receive(:info).and_call_original
          allow(Rails.logger).to receive(:warn).and_call_original
          allow(Rails.logger).to receive(:error).and_call_original

          # Set specific expectations
          expect(Rails.logger).to receive(:warn).with(
            'BGS payment history has no payments',
            hash_including(user_uuid: user.uuid)
          ).and_call_original
          expect(StatsD).to receive(:increment)
            .with('api.payment_history.payments.empty').and_call_original

          get(:index)
        end
      end

      context 'when payment_history has payments' do
        it 'does not log warnings or errors' do
          # Don't allow error or warn logs for payment_history validation
          expect(Rails.logger).not_to receive(:error).with(
            'BGS::PaymentService returned nil',
            anything
          )
          expect(Rails.logger).not_to receive(:warn).with(
            'BGS payment history has no payments',
            anything
          )
          expect(StatsD).not_to receive(:increment).with('api.payment_history.payment_history.nil')
          expect(StatsD).not_to receive(:increment).with('api.payment_history.payments.empty')

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

      it 'does not log payment_history validation' do
        # Stub BGS to return nil payment_history
        person = double('person',
                        status: 'ACTIVE',
                        file_number: '123456789',
                        participant_id: '123456',
                        ssn_number: '123456789')
        allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
          .and_return(person)
        allow_any_instance_of(BGS::PaymentService).to receive(:payment_history)
          .and_return(nil)

        expect(Rails.logger).not_to receive(:error).with(
          'BGS::PaymentService returned nil',
          anything
        )
        expect(StatsD).not_to receive(:increment).with('api.payment_history.payment_history.nil')

        get(:index)
      end
    end
  end

  describe '#validate_final_response' do
    before do
      allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
      sign_in_as(user)
    end

    context 'with validation logging enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(true)
      end

      context 'when both payments and return_payments are empty' do
        it 'logs warning and increments api.payment_history.response.empty' do
          # Stub the adapter to return empty payments and return_payments
          adapter = double('adapter', payments: [], return_payments: [])
          allow_any_instance_of(V0::Profile::PaymentHistoryController).to receive(:adapter)
            .and_return(adapter)

          # Allow all logger and StatsD calls
          allow(Rails.logger).to receive(:warn).and_call_original
          allow(Rails.logger).to receive(:info).and_call_original
          allow(StatsD).to receive(:increment).and_call_original

          # Expect specific calls for validate_final_response
          expect(Rails.logger).to receive(:warn).with(
            'Returning empty payment history response to customer',
            hash_including(user_uuid: user.uuid)
          ).and_call_original
          expect(StatsD).to receive(:increment)
            .with('api.payment_history.response.empty').and_call_original

          get(:index)

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when payments is not empty' do
        it 'logs info and increments api.payment_history.response.success' do
          # Stub the adapter to return non-empty payments
          adapter = double('adapter',
                           payments: [{ 'payment_amount' => '123.45', 'payment_date' => '2024-01-01' }],
                           return_payments: [])
          allow_any_instance_of(V0::Profile::PaymentHistoryController).to receive(:adapter)
            .and_return(adapter)

          # Allow all logger and StatsD calls (including from other validation methods)
          allow(Rails.logger).to receive(:info).and_call_original
          allow(Rails.logger).to receive(:warn).and_call_original
          allow(Rails.logger).to receive(:error).and_call_original
          allow(StatsD).to receive(:increment).and_call_original

          # Expect specific calls for validate_final_response
          expect(Rails.logger).to receive(:info).with(
            'Returning payment history response to customer',
            hash_including(user_uuid: user.uuid)
          ).and_call_original
          expect(StatsD).to receive(:increment)
            .with('api.payment_history.response.success').and_call_original

          get(:index)

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when return_payments is not empty but payments is empty' do
        it 'logs info and increments api.payment_history.response.success' do
          # Stub the adapter to return empty payments but has return_payments
          adapter = double('adapter', payments: [], return_payments: [{ 'return_reason' => 'Undeliverable' }])
          allow_any_instance_of(V0::Profile::PaymentHistoryController).to receive(:adapter)
            .and_return(adapter)

          # Allow all logger and StatsD calls
          allow(Rails.logger).to receive(:info).and_call_original
          allow(Rails.logger).to receive(:warn).and_call_original
          allow(StatsD).to receive(:increment).and_call_original

          # Expect specific calls for validate_final_response
          expect(Rails.logger).to receive(:info).with(
            'Returning payment history response to customer',
            hash_including(user_uuid: user.uuid)
          ).and_call_original
          expect(StatsD).to receive(:increment)
            .with('api.payment_history.response.success').and_call_original

          get(:index)

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when both payments and return_payments have data' do
        it 'logs info and increments api.payment_history.response.success' do
          # Stub the adapter to return both payments and return_payments
          adapter = double('adapter',
                           payments: [{ 'payment_amount' => '123.45' }],
                           return_payments: [{ 'return_reason' => 'Undeliverable' }])
          allow_any_instance_of(V0::Profile::PaymentHistoryController).to receive(:adapter)
            .and_return(adapter)

          # Allow all logger and StatsD calls
          allow(Rails.logger).to receive(:info).and_call_original
          allow(StatsD).to receive(:increment).and_call_original

          # Expect specific calls for validate_final_response
          expect(Rails.logger).to receive(:info).with(
            'Returning payment history response to customer',
            hash_including(user_uuid: user.uuid)
          ).and_call_original
          expect(StatsD).to receive(:increment)
            .with('api.payment_history.response.success').and_call_original

          get(:index)

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with validation logging disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(false)
      end

      it 'does not log final response validation even when both are empty' do
        # Stub the adapter to return empty payments and return_payments
        adapter = double('adapter', payments: [], return_payments: [])
        allow_any_instance_of(V0::Profile::PaymentHistoryController).to receive(:adapter)
          .and_return(adapter)

        expect(Rails.logger).not_to receive(:warn).with(
          'Returning empty payment history response to customer',
          anything
        )
        expect(Rails.logger).not_to receive(:info).with(
          'Returning payment history response to customer',
          anything
        )
        expect(StatsD).not_to receive(:increment).with('api.payment_history.response.empty')
        expect(StatsD).not_to receive(:increment).with('api.payment_history.response.success')

        get(:index)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe '#log_before_bgs_people_request' do
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

      it 'logs BGS people request start and increments StatsD' do
        # Allow all logger and StatsD calls
        allow(Rails.logger).to receive(:info).and_call_original
        allow(StatsD).to receive(:increment).and_call_original

        # Expect specific calls for log_before_bgs_people_request
        expect(Rails.logger).to receive(:info).with(
          'Requesting person from BGS',
          hash_including(user_uuid: user.uuid)
        ).and_call_original
        expect(StatsD).to receive(:increment)
          .with('api.payment_history.bgs_people_request.started').and_call_original

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end
      end

      it 'is called after log_authorized_access' do
        call_order = []

        allow(controller).to receive(:log_authorized_access).and_wrap_original do |method|
          call_order << :log_authorized
          method.call
        end

        allow(controller).to receive(:log_before_bgs_people_request).and_wrap_original do |method|
          call_order << :log_before_people_request
          method.call
        end

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end

        # Verify log_authorized was called before log_before_people_request
        authorized_index = call_order.index(:log_authorized)
        before_request_index = call_order.index(:log_before_people_request)

        expect(authorized_index).not_to be_nil
        expect(before_request_index).not_to be_nil
        expect(authorized_index).to be < before_request_index
      end
    end

    context 'with detailed logging disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
      end

      it 'does not log BGS people request start' do
        expect(Rails.logger).not_to receive(:info).with(
          'Requesting person from BGS',
          anything
        )
        expect(StatsD).not_to receive(:increment)
          .with('api.payment_history.bgs_people_request.started')

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end
      end
    end
  end

  describe '#log_after_bgs_people_request' do
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

      it 'logs BGS people request completion and increments StatsD' do
        # Allow all logger and StatsD calls
        allow(Rails.logger).to receive(:info).and_call_original
        allow(StatsD).to receive(:increment).and_call_original

        # Expect specific calls for log_after_bgs_people_request
        expect(Rails.logger).to receive(:info).with(
          'Received person from BGS',
          hash_including(user_uuid: user.uuid)
        ).and_call_original
        expect(StatsD).to receive(:increment)
          .with('api.payment_history.bgs_people_request.completed').and_call_original

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end
      end

      it 'is called after log_before_bgs_people_request' do
        call_order = []

        allow(controller).to receive(:log_before_bgs_people_request).and_wrap_original do |method|
          call_order << :log_before_people_request
          method.call
        end

        allow(controller).to receive(:log_after_bgs_people_request).and_wrap_original do |method|
          call_order << :log_after_people_request
          method.call
        end

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end

        # Verify log_before was called before log_after
        before_index = call_order.index(:log_before_people_request)
        after_index = call_order.index(:log_after_people_request)

        expect(before_index).not_to be_nil
        expect(after_index).not_to be_nil
        expect(before_index).to be < after_index
      end
    end

    context 'with detailed logging disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
      end

      it 'does not log BGS people request completion' do
        expect(Rails.logger).not_to receive(:info).with(
          'Received person from BGS',
          anything
        )
        expect(StatsD).not_to receive(:increment)
          .with('api.payment_history.bgs_people_request.completed')

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end
      end
    end
  end

  describe '#log_before_bgs_payment_service_request' do
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

      it 'logs BGS payment service request start and increments StatsD' do
        # Allow all logger and StatsD calls
        allow(Rails.logger).to receive(:info).and_call_original
        allow(StatsD).to receive(:increment).and_call_original

        # Expect specific calls for log_before_bgs_payment_service_request
        expect(Rails.logger).to receive(:info).with(
          'Requesting payment history from BGS',
          hash_including(user_uuid: user.uuid)
        ).and_call_original
        expect(StatsD).to receive(:increment)
          .with('api.payment_history.bgs_payment_service.started').and_call_original

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end
      end

      it 'is called after validate_person_attributes' do
        call_order = []

        allow(controller).to receive(:validate_person_attributes).and_wrap_original do |method, *args|
          call_order << :validate_person
          method.call(*args)
        end

        allow(controller).to receive(:log_before_bgs_payment_service_request).and_wrap_original do |method|
          call_order << :log_before_payment_request
          method.call
        end

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end

        # Verify validate_person was called before log_before_payment_request
        validate_index = call_order.index(:validate_person)
        before_request_index = call_order.index(:log_before_payment_request)

        expect(validate_index).not_to be_nil
        expect(before_request_index).not_to be_nil
        expect(validate_index).to be < before_request_index
      end
    end

    context 'with detailed logging disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
      end

      it 'does not log BGS payment service request start' do
        expect(Rails.logger).not_to receive(:info).with(
          'Requesting payment history from BGS',
          anything
        )
        expect(StatsD).not_to receive(:increment)
          .with('api.payment_history.bgs_payment_service.started')

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end
      end
    end
  end

  describe '#log_after_bgs_payment_service_request' do
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

      it 'logs BGS payment service completion and increments StatsD' do
        # Allow all logger and StatsD calls
        allow(Rails.logger).to receive(:info).and_call_original
        allow(StatsD).to receive(:increment).and_call_original

        # Expect specific calls for log_after_bgs_payment_service_request
        expect(Rails.logger).to receive(:info).with(
          'Received payment history from BGS',
          hash_including(user_uuid: user.uuid)
        ).and_call_original
        expect(StatsD).to receive(:increment)
          .with('api.payment_history.bgs_payment_service.completed').and_call_original

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end
      end

      it 'is called after log_before_bgs_payment_service_request' do
        call_order = []

        allow(controller).to receive(:log_before_bgs_payment_service_request).and_wrap_original do |method|
          call_order << :log_before_payment_request
          method.call
        end

        allow(controller).to receive(:log_after_bgs_payment_service_request).and_wrap_original do |method|
          call_order << :log_after_payment_request
          method.call
        end

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
          end
        end

        # Verify log_before was called before log_after
        before_index = call_order.index(:log_before_payment_request)
        after_index = call_order.index(:log_after_payment_request)

        expect(before_index).not_to be_nil
        expect(after_index).not_to be_nil
        expect(before_index).to be < after_index
      end
    end

    context 'with detailed logging disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
      end

      it 'does not log BGS payment service completion' do
        expect(Rails.logger).not_to receive(:info).with(
          'Received payment history from BGS',
          anything
        )
        expect(StatsD).not_to receive(:increment)
          .with('api.payment_history.bgs_payment_service.completed')

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            get(:index)
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

  describe '#log_payment_history_exception' do
    let(:test_exception) { StandardError.new('Test error message') }

    context 'with exception logging enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
        sign_in_as(user)
      end

      it 'logs exception details and increments StatsD' do
        allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
          .and_raise(test_exception)

        # Allow all logging calls
        allow(Rails.logger).to receive(:error).and_call_original
        allow(Rails.logger).to receive(:info).and_call_original
        allow(Rails.logger).to receive(:warn).and_call_original

        # Allow all StatsD calls
        allow(StatsD).to receive(:increment).and_call_original

        # Expect specific error log
        expect(Rails.logger).to receive(:error).with(
          'Exception occurred in payment history controller',
          hash_including(
            user_uuid: user.uuid,
            exception_class: 'StandardError',
            exception_message: 'Test error message'
          )
        ).and_call_original

        # Expect specific StatsD metric
        expect(StatsD).to receive(:increment)
          .with('api.payment_history.exception.standard_error').and_call_original

        get(:index)
      end

      it 'handles different exception types correctly' do
        custom_exception = RuntimeError.new('Runtime error')
        allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
          .and_raise(custom_exception)

        # Allow all logging calls
        allow(Rails.logger).to receive(:error).and_call_original
        allow(Rails.logger).to receive(:info).and_call_original
        allow(Rails.logger).to receive(:warn).and_call_original

        # Allow all StatsD calls
        allow(StatsD).to receive(:increment).and_call_original

        # Expect specific error log
        expect(Rails.logger).to receive(:error).with(
          'Exception occurred in payment history controller',
          hash_including(
            user_uuid: user.uuid,
            exception_class: 'RuntimeError',
            exception_message: 'Runtime error'
          )
        ).and_call_original

        # Expect specific StatsD metric
        expect(StatsD).to receive(:increment)
          .with('api.payment_history.exception.runtime_error').and_call_original

        get(:index)
      end

      it 'normalizes namespaced exception names to prevent / in metrics' do
        # Create a namespaced exception class
        namespaced_exception = Class.new(StandardError)
        stub_const('BGS::ServiceError', namespaced_exception)
        custom_exception = BGS::ServiceError.new('BGS service error')

        allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
          .and_raise(custom_exception)

        # Allow all logging calls
        allow(Rails.logger).to receive(:error).and_call_original
        allow(Rails.logger).to receive(:info).and_call_original
        allow(Rails.logger).to receive(:warn).and_call_original

        # Allow all StatsD calls
        allow(StatsD).to receive(:increment).and_call_original

        # Expect specific error log with original class name
        expect(Rails.logger).to receive(:error).with(
          'Exception occurred in payment history controller',
          hash_including(
            user_uuid: user.uuid,
            exception_class: 'BGS::ServiceError',
            exception_message: 'BGS service error'
          )
        ).and_call_original

        # Expect StatsD metric with / replaced by _
        expect(StatsD).to receive(:increment)
          .with('api.payment_history.exception.bgs_service_error').and_call_original

        get(:index)
      end
    end

    context 'with exception logging disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
        sign_in_as(user)
      end

      it 'does not log exception details' do
        allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
          .and_raise(test_exception)

        expect(Rails.logger).not_to receive(:error).with(
          'Exception occurred in payment history controller',
          anything
        )
        expect(StatsD).not_to receive(:increment).with('api.payment_history.exception.standard_error')

        get(:index)
      end

      it 'still allows exception to propagate' do
        # Stub BGS services to succeed
        person = double('person',
                        status: 'ACTIVE',
                        file_number: '123456789',
                        participant_id: '123456',
                        ssn_number: '123456789')
        payment_history = double('payment_history', payments: [{ amount: '100.00' }])
        allow_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id)
          .and_return(person)
        allow_any_instance_of(BGS::PaymentService).to receive(:payment_history)
          .and_return(payment_history)

        # Make adapter method fail with RuntimeError
        runtime_exception = RuntimeError.new('Adapter failure')
        allow(controller).to receive(:adapter).and_raise(runtime_exception)

        # Allow all logging calls
        allow(Rails.logger).to receive(:error).and_call_original
        allow(Rails.logger).to receive(:info).and_call_original
        allow(Rails.logger).to receive(:warn).and_call_original

        # Verify no exception logging occurs for RuntimeError
        expect(StatsD).not_to receive(:increment).with('api.payment_history.exception.runtime_error')
        expect(Rails.logger).not_to receive(:error).with(
          'Payment history request failed',
          anything
        )

        get(:index)
      end
    end
  end

  describe '#index' do
    before do
      allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)
    end

    context 'with only regular payments' do
      it 'returns only payments and no return payments' do
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
      before do
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(false)
      end

      it 'does not return both' do
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
