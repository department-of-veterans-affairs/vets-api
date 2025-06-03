# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/veteran_verification/constants'
require 'lighthouse/veteran_verification/service'
require 'lighthouse/service_exception'

RSpec.describe VeteranVerification::Service do
  before(:all) do
    @service = VeteranVerification::Service.new
  end

  describe 'making requests' do
    context 'valid requests' do
      before do
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('blahblech')
      end

      describe 'when requesting disability_rating' do
        let(:icn) { '123498767V234859' }

        it 'retrieves rated disabilities from the Lighthouse API' do
          VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response', VCR::MATCH_EVERYTHING) do
            response = @service.get_rated_disabilities(icn, '', '')
            expect(response['data']['id']).to eq('12303')
          end
        end

        Lighthouse::ServiceException::ERROR_MAP.except(422, 499, 501).each do |status, error_class|
          it "throws a #{status} error if Lighthouse sends it back" do
            expect do
              test_error(
                "lighthouse/veteran_verification/disability_rating/#{status == 404 ? '404_ICN' : status}_response"
              )
            end.to raise_error error_class
          end

          def test_error(cassette_path)
            VCR.use_cassette(cassette_path) do
              @service.get_rated_disabilities(icn, '', '')
            end
          end
        end

        it 'handles unknown errors' do
          expect do
            test_error(
              'lighthouse/veteran_verification/disability_rating/405_response'
            )
          end.to raise_error Common::Exceptions::ServiceError
        end
      end

      describe 'when requesting status' do
        context 'when confirmed' do
          let(:user) { build(:user, icn: '1012667145V762142') }
          let(:service) { VeteranVerification::Service.new(user) }

          it 'retrieves veteran confirmation status from the Lighthouse API' do
            VCR.use_cassette('lighthouse/veteran_verification/status/200_response', VCR::MATCH_EVERYTHING) do
              expect(StatsD).to receive(:increment).with(
                VeteranVerification::Constants::STATSD_VET_VERIFICATION_TOTAL_KEY
              )
              expect(Rails.logger).to receive(:info).with('Vet Verification Status Success: confirmed',
                                                          { confirmed: true })

              response = service.get_vet_verification_status(user.icn, '', '')

              expect(response['data']['id']).to eq('1012667145V762142')
              expect(response['data']['type']).to eq('veteran_status_confirmations')
              expect(response['data']['attributes']['veteran_status']).to eq('confirmed')
            end
          end
        end

        context 'on error' do
          let(:user) { build(:user, icn: '1012666182V20') }
          let(:service) { VeteranVerification::Service.new(user) }

          before do
            allow(Flipper).to receive(:enabled?).with(:vet_status_stage_1, user).and_return(false) # rubocop:disable Naming/VariableNumber
          end

          it 'retrieves error status from the Lighthouse API' do
            VCR.use_cassette('lighthouse/veteran_verification/status/200_error_response', VCR::MATCH_EVERYTHING) do
              expect(StatsD).to receive(:increment).with(
                VeteranVerification::Constants::STATSD_VET_VERIFICATION_TOTAL_KEY
              )
              expect(Rails.logger).to receive(:info).with(
                'Vet Verification Status Success: not confirmed',
                { not_confirmed: true, not_confirmed_reason: 'ERROR' }
              )

              response = service.get_vet_verification_status(user.icn, '', '')

              expect(response['data']['id']).to eq('1012666182V20')
              expect(response['data']['attributes']['veteran_status']).to eq('not confirmed')
              expect(response['data']['attributes']).to have_key('not_confirmed_reason')
              expect(response['data']['message']).to eq(VeteranVerification::Constants::ERROR_MESSAGE)
              expect(response['data']['title']).to eq(VeteranVerification::Constants::ERROR_MESSAGE_TITLE)
              expect(response['data']['status']).to eq(VeteranVerification::Constants::ERROR_MESSAGE_STATUS)
            end
          end
        end

        context 'when not title 38' do
          let(:user) { build(:user, icn: '1012666182V203559') }
          let(:service) { VeteranVerification::Service.new(user) }

          before do
            allow(Flipper).to receive(:enabled?).with(:vet_status_stage_1, user).and_return(false) # rubocop:disable Naming/VariableNumber
          end

          it 'retrieves veteran not confirmed status from the Lighthouse API' do
            VCR.use_cassette('lighthouse/veteran_verification/status/200_not_confirmed_response',
                             VCR::MATCH_EVERYTHING) do
              expect(Rails.logger).to receive(:info).with(
                'Vet Verification Status Success: not confirmed',
                { not_confirmed: true, not_confirmed_reason: 'NOT_TITLE_38' }
              )

              response = service.get_vet_verification_status(user.icn, '', '')

              expect(response['data']['id']).to eq('1012666182V203559')
              expect(response['data']['attributes']['veteran_status']).to eq('not confirmed')
              expect(response['data']['attributes']).to have_key('not_confirmed_reason')
              expect(response['data']['message']).to eq(VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE)
              expect(response['data']['title']).to eq(VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE_TITLE)
              expect(response['data']['status']).to eq(VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE_STATUS)
            end
          end
        end

        context 'when person not found' do
          let(:user) { build(:user, icn: '1012667145V762141') }
          let(:service) { VeteranVerification::Service.new(user) }

          before do
            allow(Flipper).to receive(:enabled?).with(:vet_status_stage_1, user).and_return(false) # rubocop:disable Naming/VariableNumber
          end

          it 'retrieves veteran not found status from the Lighthouse API' do
            VCR.use_cassette('lighthouse/veteran_verification/status/200_person_not_found_response',
                             VCR::MATCH_EVERYTHING) do
              expect(Rails.logger).to receive(:info).with(
                'Vet Verification Status Success: not confirmed',
                { not_confirmed: true, not_confirmed_reason: 'PERSON_NOT_FOUND' }
              )

              response = service.get_vet_verification_status(user.icn, '', '')

              expect(response['data']['id']).to be_nil
              expect(response['data']['attributes']['veteran_status']).to eq('not confirmed')
              expect(response['data']['attributes']).to have_key('not_confirmed_reason')
              expect(response['data']['message']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE)
              expect(response['data']['title']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_TITLE)
              expect(response['data']['status']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_STATUS)
            end
          end
        end

        context 'when more research required' do
          let(:user) { build(:user, icn: '1012667145V762149') }
          let(:service) { VeteranVerification::Service.new(user) }

          before do
            allow(Flipper).to receive(:enabled?).with(:vet_status_stage_1, user).and_return(false) # rubocop:disable Naming/VariableNumber
          end

          it 'retrieves more research required status from the Lighthouse API' do
            VCR.use_cassette('lighthouse/veteran_verification/status/200_more_research_required_response',
                             VCR::MATCH_EVERYTHING) do
              response = service.get_vet_verification_status(user.icn, '', '')

              expect(response['data']['id']).to eq('1012667145V762149')
              expect(response['data']['attributes']['veteran_status']).to eq('not confirmed')
              expect(response['data']['attributes']).to have_key('not_confirmed_reason')
              expect(response['data']['message']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE)
              expect(response['data']['title']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_TITLE)
              expect(response['data']['status']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_STATUS)
            end
          end
        end

        context 'encountering exceptions' do
          let(:user) { build(:user, icn: '1012667145V762142') }
          let(:service) { VeteranVerification::Service.new(user) }

          Lighthouse::ServiceException::ERROR_MAP.except(404, 422, 499, 501).each do |status, error_class|
            it "throws a #{status} error if Lighthouse sends it back" do
              expect(StatsD).to receive(:increment).with(
                VeteranVerification::Constants::STATSD_VET_VERIFICATION_TOTAL_KEY
              )
              expect(StatsD).to receive(:increment).with(
                VeteranVerification::Constants::STATSD_VET_VERIFICATION_FAIL_KEY
              )
              expect do
                test_error(
                  "lighthouse/veteran_verification/status/#{status}_response"
                )
              end.to raise_error error_class
            end

            def test_error(cassette_path)
              VCR.use_cassette(cassette_path) do
                service.get_vet_verification_status(user.icn, '', '')
              end
            end
          end
        end
      end

      describe 'with titled alerts enabled' do
        let(:icn) { '1012667145V762142' }

        before do
          allow(Flipper).to receive(:enabled?).with(:vet_status_stage_1, user).and_return(true) # rubocop:disable Naming/VariableNumber
        end

        context 'on error' do
          let(:user) { build(:user, icn: '1012666182V20') }
          let(:service) { VeteranVerification::Service.new(user) }

          before do
            allow(Flipper).to receive(:enabled?).with(:vet_status_stage_1, user).and_return(true) # rubocop:disable Naming/VariableNumber
          end

          it 'retrieves error status from the Lighthouse API' do
            VCR.use_cassette('lighthouse/veteran_verification/status/200_error_response', VCR::MATCH_EVERYTHING) do
              expect(StatsD).to receive(:increment).with(
                VeteranVerification::Constants::STATSD_VET_VERIFICATION_TOTAL_KEY
              )
              expect(Rails.logger).to receive(:info).with(
                'Vet Verification Status Success: not confirmed',
                { not_confirmed: true, not_confirmed_reason: 'ERROR' }
              )

              response = service.get_vet_verification_status(user.icn, '', '')

              expect(response['data']['id']).to eq('1012666182V20')
              expect(response['data']['attributes']['veteran_status']).to eq('not confirmed')
              expect(response['data']['attributes']).to have_key('not_confirmed_reason')
              expect(response['data']['message']).to eq(VeteranVerification::Constants::ERROR_MESSAGE_UPDATED)
              expect(response['data']['title']).to eq(VeteranVerification::Constants::ERROR_MESSAGE_TITLE)
              expect(response['data']['status']).to eq(VeteranVerification::Constants::ERROR_MESSAGE_STATUS)
            end
          end
        end

        context 'when not title 38' do
          let(:user) { build(:user, icn: '1012666182V203559') }
          let(:service) { VeteranVerification::Service.new(user) }

          before do
            allow(Flipper).to receive(:enabled?).with(:vet_status_stage_1, user).and_return(true) # rubocop:disable Naming/VariableNumber
          end

          it 'retrieves veteran not confirmed status from the Lighthouse API' do
            VCR.use_cassette('lighthouse/veteran_verification/status/200_not_confirmed_response',
                             VCR::MATCH_EVERYTHING) do
              expect(Rails.logger).to receive(:info).with(
                'Vet Verification Status Success: not confirmed',
                { not_confirmed: true, not_confirmed_reason: 'NOT_TITLE_38' }
              )

              response = service.get_vet_verification_status(user.icn, '', '')

              expect(response['data']['id']).to eq('1012666182V203559')
              expect(response['data']['attributes']['veteran_status']).to eq('not confirmed')
              expect(response['data']['attributes']).to have_key('not_confirmed_reason')
              expect(response['data']['message']).to eq(VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE_UPDATED)
              expect(response['data']['title']).to eq(VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE_TITLE)
              expect(response['data']['status']).to eq(VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE_STATUS)
            end
          end
        end

        context 'when person not found' do
          let(:user) { build(:user, icn: '1012667145V762141') }
          let(:service) { VeteranVerification::Service.new(user) }

          before do
            allow(Flipper).to receive(:enabled?).with(:vet_status_stage_1, user).and_return(true) # rubocop:disable Naming/VariableNumber
          end

          it 'retrieves veteran not found status from the Lighthouse API' do
            VCR.use_cassette('lighthouse/veteran_verification/status/200_person_not_found_response',
                             VCR::MATCH_EVERYTHING) do
              expect(Rails.logger).to receive(:info).with(
                'Vet Verification Status Success: not confirmed',
                { not_confirmed: true, not_confirmed_reason: 'PERSON_NOT_FOUND' }
              )

              response = service.get_vet_verification_status(user.icn, '', '')

              expect(response['data']['id']).to be_nil
              expect(response['data']['attributes']['veteran_status']).to eq('not confirmed')
              expect(response['data']['attributes']).to have_key('not_confirmed_reason')
              expect(response['data']['message']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE)
              expect(response['data']['title']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_TITLE)
              expect(response['data']['status']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_STATUS)
            end
          end
        end

        context 'when more research required' do
          let(:user) { build(:user, icn: '1012667145V762149') }
          let(:service) { VeteranVerification::Service.new(user) }

          before do
            allow(Flipper).to receive(:enabled?).with(:vet_status_stage_1, user).and_return(true) # rubocop:disable Naming/VariableNumber
          end

          it 'retrieves more research required status from the Lighthouse API' do
            VCR.use_cassette('lighthouse/veteran_verification/status/200_more_research_required_response',
                             VCR::MATCH_EVERYTHING) do
              response = service.get_vet_verification_status(user.icn, '', '')

              expect(response['data']['id']).to eq('1012667145V762149')
              expect(response['data']['attributes']['veteran_status']).to eq('not confirmed')
              expect(response['data']['attributes']).to have_key('not_confirmed_reason')
              expect(response['data']['message']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_UPDATED)
              expect(response['data']['title']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_TITLE)
              expect(response['data']['status']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_STATUS)
            end
          end
        end
      end
    end
  end
end
