# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

RSpec.describe 'V0::Profile::ServiceHistory', type: :request do
  include SchemaMatchers
  include ErrorDetails

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  describe 'GET /v0/profile/service_history' do
    let(:user) { build(:user, :loa3) }

    before do
      sign_in(user)
    end

    # The following provides a description of the different termination reason codes:
    # •	"S" Separation From Personnel Category
    # •	"C" Completion of Active Service Period
    # •	"D" Death while in personnel category or organization
    # •	"W" Not Applicable

    context 'when successful' do
      it 'matches the service history schema' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          get '/v0/profile/service_history'

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('service_history_response')
        end
      end

      it 'matches the service history schema when camel-inflected' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          get '/v0/profile/service_history', headers: inflection_header

          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('service_history_response')
        end
      end

      it 'returns a single service history episode and vet_status_eligibility' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          get '/v0/profile/service_history'

          json = json_body_for(response)
          episode = json.dig('attributes', 'service_history').first

          expect(episode['branch_of_service']).to eq('Army')
          expect(episode['begin_date']).to eq('2002-02-02')
          expect(episode['end_date']).to eq('2008-12-01')
          expect(episode['period_of_service_type_code']).to eq('N')
          expect(episode['period_of_service_type_text']).to eq('National Guard member')
          expect(episode['termination_reason_code']).to eq('S')
          expect(episode['termination_reason_text']).to eq('Separation from personnel category or organization')
          expect(json.dig('attributes', 'vet_status_eligibility')).to eq(
            { 'confirmed' => true, 'message' => [], 'title' => '', 'status' => '' }
          )
        end
      end

      it 'returns no service history episodes' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200_empty') do
          get '/v0/profile/service_history'
          json = json_body_for(response)
          episodes = json.dig('attributes', 'service_history')
          vet_status_eligibility = json.dig('attributes', 'vet_status_eligibility')

          expect(response).to be_ok
          expect(episodes.count).to eq(0)
          expect(vet_status_eligibility).to eq({ 'confirmed' => false,
                                                 'message' => VeteranVerification::Constants::NOT_FOUND_MESSAGE,
                                                 'title' => VeteranVerification::Constants::NOT_FOUND_MESSAGE_TITLE,
                                                 'status' => VeteranVerification::Constants::NOT_FOUND_MESSAGE_STATUS })
        end
      end

      context 'when academy attendance flag is off' do
        before do
          Flipper.disable(:profile_show_military_academy_attendance) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        end

        it 'returns military service episodes only' do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
            get '/v0/profile/service_history'

            json = json_body_for(response)
            episodes = json.dig('attributes', 'service_history')

            expect(episodes.count).to eq(3)
            episodes.each do |e|
              expect(e['service_type']).to eq(VAProfile::Models::ServiceHistory::MILITARY_SERVICE)
              expect(e['branch_of_service']).not_to be_nil
              expect(e['begin_date']).not_to be_nil
              expect(e['end_date']).not_to be_nil
              expect(e['period_of_service_type_code']).not_to be_nil
              expect(e['period_of_service_type_text']).not_to be_nil
              expect(e['termination_reason_code']).not_to be_nil
              expect(e['termination_reason_text']).not_to be_nil
            end
          end
        end
      end

      context 'when academy attendance flag is on' do
        before do
          Flipper.enable(:profile_show_military_academy_attendance) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        end

        it 'returns military service and academy attendance episodes' do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
            get '/v0/profile/service_history'

            json = json_body_for(response)
            episodes = json.dig('attributes', 'service_history')

            expect(episodes.count).to eq(5)
            episodes.each do |e|
              expect(e['branch_of_service']).not_to be_nil
              expect(e['begin_date']).not_to be_nil
              expect(e['end_date']).not_to be_nil
              unless e['service_type'] == VAProfile::Models::ServiceHistory::MILITARY_SERVICE
                expect(e['service_type']).to eq(VAProfile::Models::ServiceHistory::ACADEMY_ATTENDANCE)
              end
            end
          end
        end
      end
    end

    context 'when not successful' do
      context 'when external service returns 400 response' do
        it 'returns 400 with nil service history' do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_history_400') do
            get '/v0/profile/service_history'

            expect(response).to have_http_status(:bad_request)
          end
        end
      end

      context 'when external service returns 500 response' do
        it 'returns 400 with nil service history' do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_history_500') do
            get '/v0/profile/service_history'
            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end

    describe 'eligible benefits logging' do
      context 'with log_eligible_benefits feature flag on' do
        before { allow(Flipper).to receive(:enabled?).with(:log_eligible_benefits).and_return(true) }

        context 'when service history response succeeds' do
          it 'logs eligible benefits' do
            expect(Lighthouse::BenefitsDiscovery::LogEligibleBenefitsJob).to receive(:perform_async).with(
              user.uuid,
              [{
                startDate: '2002-02-02',
                endDate: '2008-12-01',
                dischargeStatus: 'GENERAL_DISCHARGE',
                branchOfService: 'ARMY'
              }]
            )
            VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
              get '/v0/profile/service_history'
            end

            expect(response).to have_http_status(:ok)
          end
        end

        context 'when service history response fails' do
          it 'does not log eligible benefits' do
            expect(Lighthouse::BenefitsDiscovery::LogEligibleBenefitsJob).not_to receive(:perform_async)
            VCR.use_cassette('va_profile/military_personnel/post_read_service_history_500') do
              get '/v0/profile/service_history'
            end

            expect(response).to have_http_status(:bad_request)
          end
        end

        context 'when params creation fails' do
          it 'logs error, does not log benefits, and does not cause request error' do
            allow(BenefitsDiscovery::Params).to receive(:service_history_params).and_raise(StandardError.new('oops'))
            expect(Rails.logger).to receive(:error).with('Error logging eligible benefits: oops')
            expect(Lighthouse::BenefitsDiscovery::LogEligibleBenefitsJob).not_to receive(:perform_async)
            VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
              get '/v0/profile/service_history'
            end

            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'with log_eligible_benefits feature flag off' do
        before { allow(Flipper).to receive(:enabled?).with(:log_eligible_benefits).and_return(false) }

        it 'does not log eligible benefits' do
          expect(Lighthouse::BenefitsDiscovery::LogEligibleBenefitsJob).not_to receive(:perform_async)
          VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
            get '/v0/profile/service_history'
          end
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
