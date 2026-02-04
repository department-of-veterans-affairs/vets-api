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
