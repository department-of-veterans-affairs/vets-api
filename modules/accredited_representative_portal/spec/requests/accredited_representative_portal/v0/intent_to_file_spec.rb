# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::IntentToFileController, type: :request do
  let(:poa_code) { '067' }
  let(:poa_check_vcr_response) { '200_response' }
  let(:poa_check_vcr_path) { 'lighthouse/benefits_claims/power_of_attorney' }
  let!(:test_user) do
    create(:representative_user, email: 'test@va.gov', icn: '123498767V234859', all_emails: ['test@va.gov'])
  end
  let!(:vso) { create(:organization, poa: poa_code) }

  let!(:representative) do
    create(:representative,
           :vso,
           email: test_user.email,
           representative_id: '357458',
           poa_codes: [poa_code])
  end
  let(:veteran_query_params) do
    'veteranFirstName=Derrick&veteranLastName=Reid&veteranSsn=666468765&veteranDateOfBirth=1976-01-16'
  end
  let(:survivor_query_params) do
    "#{veteran_query_params}&claimantFirstName=Claimanty&claimantLastName=Jane" \
      '&claimantSsn=011223344&claimantDateOfBirth=1996-08-26'
  end

  before do
    Flipper.disable :accredited_representative_portal_skip_itf_check
    VCR.configure do |c|
      c.debug_logger = File.open('record.log', 'w')
    end
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
    login_as(test_user)
    allow(AccreditedRepresentativePortal::ClaimantLookupService).to receive(:get_icn).with(
      'Derrick', 'Reid', '666468765', '1976-01-16'
    ).and_return('123498767V234859')
    allow(AccreditedRepresentativePortal::ClaimantLookupService).to receive(:get_icn).with(
      'Claimanty', 'Jane', '011223344', '1996-08-26'
    ).and_return('123498767V112233')
  end

  around do |example|
    VCR.use_cassette(
      "#{poa_check_vcr_path}/#{poa_check_vcr_response}",
      allow_playback_repeats: true
    ) do
      example.run
    end
  end

  describe 'GET /accredited_representative_portal/v0/intent_to_file' do
    context 'veteran claimant' do
      context 'bad or missing filing type' do
        it 'returns the appropriate error message' do
          get('/accredited_representative_portal/v0/intent_to_file/?benefitType=none')
          expect(response).to have_http_status(:bad_request)
        end
      end

      context 'ITF not found in Lighthouse' do
        it 'returns 404' do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/404_response') do
            get("/accredited_representative_portal/v0/intent_to_file/?benefitType=compensation&#{veteran_query_params}")
            expect(response).to have_http_status(:not_found)
          end
        end
      end

      context 'itf check skipped' do
        it 'returns 404' do
          Flipper.enable :accredited_representative_portal_skip_itf_check
          get("/accredited_representative_portal/v0/intent_to_file/?benefitType=compensation&#{veteran_query_params}")
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'veteran cannot be found' do
        before do
          allow(AccreditedRepresentativePortal::ClaimantLookupService).to receive(:get_icn).and_raise(
            Common::Exceptions::RecordNotFound, 'Claimant not found'
          )
        end

        it 'returns 400' do
          get("/accredited_representative_portal/v0/intent_to_file/?benefitType=compensation&#{veteran_query_params}")
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context 'rep does not have POA for veteran' do
      let(:poa_check_vcr_response) { '200_empty_response' }
      let(:test_user) { create(:representative_user, email: 'notallowed@example.com') }

      it 'returns 403' do
        get("/accredited_representative_portal/v0/intent_to_file/?benefitType=compensation&#{veteran_query_params}")
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'rep has filed ITF' do
      it 'returns existing ITF filing for current user' do
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
          get("/accredited_representative_portal/v0/intent_to_file/?benefitType=compensation&#{veteran_query_params}")
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['id']).to eq('193685')
        end
      end
    end

    context 'non-veteran claimant' do
      let(:poa_check_vcr_path) do
        'accredited_representative_portal/requests/accredited_representative_portal/v0/intent_to_file_spec'
      end

      context 'non-veteran claimant cannot be found' do
        before do
          allow(AccreditedRepresentativePortal::ClaimantLookupService).to receive(:get_icn).and_raise(
            Common::Exceptions::RecordNotFound, 'Claimant not found'
          )
        end

        it 'returns 400' do
          get("/accredited_representative_portal/v0/intent_to_file/?benefitType=survivor&#{survivor_query_params}")
          expect(response).to have_http_status(:bad_request)
        end
      end

      context 'rep does not have POA for claimant' do
        let(:poa_check_vcr_response) { '200_poa_check_survivor_empty_response' }
        let(:test_user) { create(:representative_user, email: 'notallowed@example.com') }

        it 'returns 403' do
          get("/accredited_representative_portal/v0/intent_to_file/?benefitType=survivor&#{survivor_query_params}")
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'rep has filed ITF' do
        let(:poa_check_vcr_response) { '200_poa_check_survivor_response' }

        it 'returns existing ITF filing for current user' do
          VCR.use_cassette(
            'accredited_representative_portal/requests/accredited_representative_portal/v0/intent_to_file_spec/' \
            '200_itf_check_survivor_response'
          ) do
            get("/accredited_representative_portal/v0/intent_to_file/?benefitType=survivor&#{survivor_query_params}")
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['data']['id']).to eq('193685')
          end
        end
      end
    end
  end

  describe 'POST /accredited_representative_portal/v0/intent_to_file' do
    let(:params) do
      {
        benefitType: 'compensation',
        veteranFullName: { first: 'Derrick', last: 'Reid' },
        veteranSsn: '666468765',
        veteranDateOfBirth: '1976-01-16'
      }
    end

    context 'valid params - veteran compensation' do
      it 'submits an intent to file' do
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_200_response') do
          post('/accredited_representative_portal/v0/intent_to_file', params:)
          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body).dig('data', 'id')).to eq '193685'
          expect(JSON.parse(response.body).dig('data', 'attributes', 'status')).to eq 'active'
        end
      end
    end

    context 'valid params - claimant survivor' do
      let(:survivor_params) do
        params.merge(
          benefitType: 'survivor',
          claimantFullName: { first: 'Claimanty', last: 'Jane' },
          claimantSsn: '011223344',
          claimantDateOfBirth: '1996-08-26'
        )
      end

      before do
        allow(AccreditedRepresentativePortal::ClaimantLookupService).to receive(:get_icn).with(
          'Claimanty', 'Jane', '011223344', '1996-08-26'
        ).and_return('123498767V234859')
      end

      it 'submits an intent to file' do
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_survivor_200_response') do
          post('/accredited_representative_portal/v0/intent_to_file', params: survivor_params)
          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body).dig('data', 'id')).to eq '193685'
          expect(JSON.parse(response.body).dig('data', 'attributes', 'status')).to eq 'active'
        end
      end
    end

    context 'rep does not have POA for veteran' do
      let(:test_user) { create(:representative_user, email: 'notallowed@example.com') }
      let(:poa_check_vcr_response) { '200_empty_response' }

      it 'returns 403' do
        post('/accredited_representative_portal/v0/intent_to_file', params:)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'unprocessable entity' do
      it 'returns a 422' do
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_422_response') do
          post('/accredited_representative_portal/v0/intent_to_file', params:)
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context 'timeout from lighthouse submission' do
      it 'returns a 503' do
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_503_response') do
          post('/accredited_representative_portal/v0/intent_to_file', params:)
          expect(response).to have_http_status(:service_unavailable)
        end
      end
    end

    # ------------------- DATADOG MONITORING TESTS -------------------
    describe 'Datadog monitoring' do
      let(:datadog_instance) { instance_double(AccreditedRepresentativePortal::Monitoring) }

      before do
        allow(AccreditedRepresentativePortal::Monitoring).to receive(:new).and_return(datadog_instance)
        allow(datadog_instance).to receive(:track_count)
      end

      context 'when submitting an ITF' do
        context 'success' do
          it 'tracks a success metric' do
            VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_200_response') do
              post('/accredited_representative_portal/v0/intent_to_file', params:)
            end

            expect(datadog_instance).to have_received(:track_count).with(
              'ar.itf.submit.attempt',
              tags: array_including('benefit_type:compensation')
            )
            expect(datadog_instance).to have_received(:track_count).with(
              'ar.itf.submit.success',
              tags: array_including('benefit_type:compensation')
            )
          end
        end

        context 'failure with 422' do
          it 'tracks an error metric with reason unprocessableentity' do
            VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_422_response') do
              post('/accredited_representative_portal/v0/intent_to_file', params:)
            end

            expect(datadog_instance).to have_received(:track_count).with(
              'ar.itf.submit.attempt',
              tags: array_including('benefit_type:compensation')
            )
            expect(datadog_instance).to have_received(:track_count).with(
              'ar.itf.submit.error',
              tags: array_including('benefit_type:compensation', 'reason:unprocessableentity')
            )
          end
        end

        context 'failure with 503' do
          it 'tracks an error metric with reason serviceunavailable' do
            VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_503_response') do
              post('/accredited_representative_portal/v0/intent_to_file', params:)
            end

            expect(datadog_instance).to have_received(:track_count).with(
              'ar.itf.submit.attempt',
              tags: array_including('benefit_type:compensation')
            )
            expect(datadog_instance).to have_received(:track_count).with(
              'ar.itf.submit.error',
              tags: array_including('benefit_type:compensation', 'reason:serviceunavailable')
            )
          end
        end

        context 'failure with ArgumentError' do
          it 'tracks an error metric with reason argument_error' do
            allow_any_instance_of(BenefitsClaims::Service).to receive(:create_intent_to_file)
              .and_raise(ArgumentError, 'bad argument')

            post('/accredited_representative_portal/v0/intent_to_file', params:)

            expect(datadog_instance).to have_received(:track_count).with(
              'ar.itf.submit.attempt',
              tags: array_including('benefit_type:compensation')
            )
            expect(datadog_instance).to have_received(:track_count).with(
              'ar.itf.submit.error',
              tags: array_including('benefit_type:compensation', 'reason:argument_error')
            )
          end
        end

        context 'failure with generic error' do
          it 'tracks an error metric with normalized reason from exception class' do
            allow_any_instance_of(BenefitsClaims::Service).to receive(:create_intent_to_file)
              .and_raise(StandardError, 'something went wrong')

            post('/accredited_representative_portal/v0/intent_to_file', params:)

            expect(datadog_instance).to have_received(:track_count).with(
              'ar.itf.submit.attempt',
              tags: array_including('benefit_type:compensation')
            )
            expect(datadog_instance).to have_received(:track_count).with(
              'ar.itf.submit.error',
              tags: array_including('benefit_type:compensation', 'reason:standarderror')
            )
          end
        end

        context 'when poa_code lookup fails' do
          before do
            # only affect Datadog tags
            allow_any_instance_of(
              AccreditedRepresentativePortal::V0::IntentToFileController
            ).to receive(:organization).and_return(nil)
          end

          it 'still submits the ITF and tracks metrics without org tag' do
            VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_200_response') do
              post('/accredited_representative_portal/v0/intent_to_file', params:)
            end

            expect(response).to have_http_status(:created)
            expect(datadog_instance).to have_received(:track_count).with(
              'ar.itf.submit.success',
              tags: array_including('benefit_type:compensation', 'org_resolve:failed')
            )
          end
        end
      end
    end
  end
end
