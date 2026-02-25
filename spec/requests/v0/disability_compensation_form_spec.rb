# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/auth/client_credentials/service'
require 'lighthouse/service_exception'
require 'disability_compensation/factories/api_provider_factory'
require 'disability_compensation/loggers/monitor'

RSpec.describe 'V0::DisabilityCompensationForm', type: :request do
  include SchemaMatchers

  let(:user) { build(:disabilities_compensation_user, icn: '123498767V234859') }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:headers_with_camel) { headers.merge('X-Key-Inflection' => 'camel') }

  before do
    Flipper.disable('disability_compensation_prevent_submission_job')
    sign_in_as(user)
  end

  describe 'Get /v0/disability_compensation_form/rated_disabilities' do
    context 'Lighthouse api provider' do
      before do
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('blahblech')
      end

      context 'with a valid 200 lighthouse response' do
        it 'matches the rated disabilities schema' do
          VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
            get('/v0/disability_compensation_form/rated_disabilities', params: nil, headers:)
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('rated_disabilities')
          end
        end

        it 'matches the rated disabilities schema when camel-inflected' do
          VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
            get '/v0/disability_compensation_form/rated_disabilities', params: nil, headers: headers_with_camel
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('rated_disabilities')
          end
        end
      end

      context 'error handling tests' do
        cassettes_directory = 'lighthouse/veteran_verification/disability_rating'

        Lighthouse::ServiceException::ERROR_MAP.except(422, 499, 501).each_key do |status|
          cassette_path = "#{cassettes_directory}/#{status == 404 ? '404_ICN' : status}_response"

          it "returns #{status} response" do
            expect(test_error(
                     cassette_path,
                     status,
                     headers
                   )).to be(true)
          end

          it "returns a #{status} response with camel-inflection" do
            expect(test_error(
                     cassette_path,
                     status,
                     headers_with_camel
                   )).to be(true)
          end
        end

        def test_error(cassette_path, status, headers)
          VCR.use_cassette(cassette_path) do
            get('/v0/disability_compensation_form/rated_disabilities', params: nil, headers:)
            expect(response).to have_http_status(status)
            expect(response).to match_response_schema('evss_errors', strict: false)
          end
        end
      end
    end
  end

  describe 'Post /v0/disability_compensation_form/suggested_conditions/:name_part' do
    before do
      create(:disability_contention_arrhythmia)
      create(:disability_contention_arteriosclerosis)
      create(:disability_contention_arthritis)
    end

    let(:conditions) { JSON.parse(response.body)['data'] }

    it 'returns matching conditions', :aggregate_failures do
      get('/v0/disability_compensation_form/suggested_conditions?name_part=art', params: nil, headers:)
      expect(response).to have_http_status(:ok)
      expect(response).to match_response_schema('suggested_conditions')
      expect(conditions.count).to eq 3
    end

    it 'returns matching conditions with camel-inflection', :aggregate_failures do
      get '/v0/disability_compensation_form/suggested_conditions?name_part=art',
          params: nil,
          headers: headers_with_camel

      expect(response).to have_http_status(:ok)
      expect(response).to match_camelized_response_schema('suggested_conditions')
      expect(conditions.count).to eq 3
    end

    it 'returns an empty array when no conditions match', :aggregate_failures do
      get('/v0/disability_compensation_form/suggested_conditions?name_part=xyz', params: nil, headers:)
      expect(response).to have_http_status(:ok)
      expect(conditions.count).to eq 0
    end

    it 'returns a 500 when name_part is missing' do
      get('/v0/disability_compensation_form/suggested_conditions', params: nil, headers:)
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'Post /v0/disability_compensation_form/submit_all_claim' do
    before do
      VCR.insert_cassette('va_profile/military_personnel/post_read_service_history_200')
      VCR.insert_cassette('lighthouse/direct_deposit/show/200_valid')
      VCR.insert_cassette('lighthouse/direct_deposit/update/200_valid')
    end

    after do
      VCR.eject_cassette('lighthouse/direct_deposit/update/200_valid')
      VCR.eject_cassette('va_profile/military_personnel/post_read_service_history_200')
      VCR.eject_cassette('lighthouse/direct_deposit/show/200_valid')
      VCR.eject_cassette('lighthouse/direct_deposit/update/200_valid')
    end

    context 'with a valid 200 evss response' do
      let(:jid) { "JID-#{SecureRandom.base64}" }

      before do
        allow(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim).to receive(:perform_async).and_return(jid)
        create(:in_progress_form, form_id: FormProfiles::VA526ez::FORM_ID, user_uuid: user.uuid)
      end

      context 'with an `all claims` claim' do
        let(:all_claims_form) { File.read 'spec/support/disability_compensation_form/submit_all_claim/all.json' }

        it 'matches the rated disabilities schema' do
          post('/v0/disability_compensation_form/submit_all_claim', params: all_claims_form, headers:)
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('submit_disability_form')
        end

        describe 'temp_toxic_exposure_optional_dates_fix' do
          # Helper that handles POST + response check + returning the submission form
          def post_and_get_submission(payload)
            post('/v0/disability_compensation_form/submit_all_claim',
                 params: JSON.generate(payload),
                 headers:)
            expect(response).to have_http_status(:ok)
            Form526Submission.last.form
          end

          # Helper to build the "optional_xx_dates" mapping
          def build_optional_xx_dates
            Form526Submission::TOXIC_EXPOSURE_DETAILS_MAPPING.transform_values do |exposures|
              if exposures.empty?
                {
                  'description' => 'some description or fallback field',
                  'startDate' => 'XXXX-03-XX',
                  'endDate' => 'XXXX-01-XX'
                }
              else
                exposures.index_with do
                  {
                    'startDate' => 'XXXX-03-XX',
                    'endDate' => 'XXXX-01-XX'
                  }
                end
              end
            end
          end

          context 'when flipper feature disability_compensation_temp_toxic_exposure_optional_dates_fix is enabled' do
            before do
              allow(Flipper).to receive(:enabled?)
                .with(:disability_compensation_temp_toxic_exposure_optional_dates_fix, anything)
                .and_return(true)
              # make sure the submission job is triggered even if there are bad dates in the toxic exposure section
              expect(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim).to receive(:perform_async).once
            end

            it 'maximal' do
              parsed_payload = JSON.parse(all_claims_form)
              # Replace the toxicExposure section with all "XXXX-XX-XX" data
              parsed_payload['form526']['toxicExposure'] = build_optional_xx_dates

              submission = post_and_get_submission(parsed_payload)
              toxic_exposure = submission.dig('form526', 'form526', 'toxicExposure')

              toxic_exposure.each do |tek, tev|
                tev.each_value do |value|
                  # Expect all optional date attributes to be removed, leaving an empty hash
                  # except for otherHerbicideLocations / specifyOtherExposures which keep description
                  expect(value).to eq({}) unless %w[otherHerbicideLocations specifyOtherExposures].include?(tek)
                end

                if %w[otherHerbicideLocations specifyOtherExposures].include?(tek)
                  expect(tev).to eq({ 'description' => 'some description or fallback field' })
                end
              end
            end

            it 'minimal' do
              parsed_payload = JSON.parse(all_claims_form)

              # Only one date is "XXXX-03-XX", the rest are valid
              parsed_payload['form526']['toxicExposure']['gulfWar1990Details']['iraq'] = {
                'startDate' => 'XXXX-03-XX',
                'endDate' => '1991-01-01'
              }

              submission = post_and_get_submission(parsed_payload)
              toxic_exposure = submission.dig('form526', 'form526', 'toxicExposure')
              gulf_war_details_iraq = toxic_exposure['gulfWar1990Details']['iraq']

              # It should have only removed the malformed startDate
              expect(gulf_war_details_iraq).to eq({ 'endDate' => '1991-01-01' })

              # The rest remain untouched
              gulf_war_details_qatar = toxic_exposure['gulfWar1990Details']['qatar']
              expect(gulf_war_details_qatar).to eq({
                                                     'startDate' => '1991-02-12',
                                                     'endDate' => '1991-06-01'
                                                   })
            end
          end

          context 'when flipper feature disability_compensation_temp_toxic_exposure_optional_dates_fix is disabled' do
            before do
              allow(Flipper).to receive(:enabled?)
                .with(:disability_compensation_temp_toxic_exposure_optional_dates_fix, anything)
                .and_return(false)
            end

            it 'fails validation' do
              parsed_payload = JSON.parse(all_claims_form)
              # Replace the toxicExposure section with all "XXXX-XX-XX" data
              parsed_payload['form526']['toxicExposure'] = build_optional_xx_dates

              post('/v0/disability_compensation_form/submit_all_claim',
                   params: JSON.generate(parsed_payload),
                   headers:)

              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'with a lot of VA Facility Treatments' do
          let(:parsed_payload) { JSON.parse(all_claims_form) }
          let(:large_array_of_treatments) { Array.new(149) { |i| "treatment_#{i + 1}" } }

          it 'does not fail to submit' do
            parsed_payload['form526']['vaTreatmentFacilities'][0]['treatedDisabilityNames'] = large_array_of_treatments
            post('/v0/disability_compensation_form/submit_all_claim', params: JSON.generate(parsed_payload), headers:)
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('submit_disability_form')
            expect(Form526Submission.count).to eq(1)
            form = Form526Submission.last.form
            treatments = form.dig('form526', 'form526', 'treatments')
            expect(treatments).not_to be_nil
            expect(treatments).not_to be_empty
            expect(treatments[0]['treatedDisabilityNames'].size).to eq(149)
          end
        end

        context 'where the startedFormVersion indicator is true' do
          it 'creates a submission that includes a toxic exposure component' do
            post('/v0/disability_compensation_form/submit_all_claim', params: all_claims_form, headers:)
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('submit_disability_form')
            expect(Form526Submission.count).to eq(1)
            form = Form526Submission.last.form
            expect(form.dig('form526', 'form526', 'startedFormVersion')).not_to be_nil
          end
        end

        context 'where the startedFormVersion indicator is false' do
          it 'does not create a submission that includes a toxic exposure component' do
            json_object = JSON.parse(all_claims_form)
            json_object['form526']['startedFormVersion'] = nil
            updated_form = JSON.generate(json_object)
            post('/v0/disability_compensation_form/submit_all_claim', params: updated_form, headers:)
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('submit_disability_form')
            expect(Form526Submission.count).to eq(1)
            form = Form526Submission.last.form
            expect(form.dig('form526', 'form526', 'startedFormVersion')).to eq('2019')
          end
        end

        describe 'toxic exposure purge tracking' do
          let(:monitor) { instance_double(DisabilityCompensation::Loggers::Monitor) }
          let(:parsed_payload) { JSON.parse(all_claims_form) }

          before do
            allow(DisabilityCompensation::Loggers::Monitor).to receive(:new).and_return(monitor)
            allow(monitor).to receive(:track_saved_claim_save_success)
            allow(monitor).to receive(:track_526_submission_with_banking_info)
            allow(monitor).to receive(:track_526_submission_without_banking_info)

            allow(Flipper).to receive(:enabled?)
              .with(:disability_526_toxic_exposure_opt_out_data_purge, anything)
              .and_return(true)
          end

          context 'when toxic exposure keys are removed' do
            it 'logs the removal' do
              # Update InProgressForm with snake_case (Rails transforms save-in-progress to snake_case)
              in_progress_form = InProgressForm.form_for_user(FormProfiles::VA526ez::FORM_ID, user)
              in_progress_form_data = JSON.parse(in_progress_form.form_data)
              in_progress_form_data['toxic_exposure'] = {
                'conditions' => { 'arthritis' => true },
                'gulf_war_1990' => { 'iraq' => true },
                'gulf_war_2001' => { 'djibouti' => true }
              }
              in_progress_form.update!(form_data: in_progress_form_data.to_json)

              # Submit with only gulfWar1990 (gulfWar2001 removed)
              parsed_payload['form526']['toxicExposure'] = {
                'conditions' => { 'arthritis' => true },
                'gulfWar1990' => { 'iraq' => true }
              }

              expect(monitor).to receive(:track_toxic_exposure_changes).with(
                hash_including(
                  in_progress_form:,
                  submitted_claim: kind_of(SavedClaim::DisabilityCompensation::Form526AllClaim),
                  submission: kind_of(Form526Submission)
                )
              )

              post('/v0/disability_compensation_form/submit_all_claim',
                   params: JSON.generate(parsed_payload),
                   headers:)
              expect(response).to have_http_status(:ok)
            end
          end

          context 'when toxic exposure is completely removed' do
            it 'logs the complete removal' do
              # Update InProgressForm with snake_case (Rails transforms save-in-progress to snake_case)
              in_progress_form = InProgressForm.form_for_user(FormProfiles::VA526ez::FORM_ID, user)
              in_progress_form_data = JSON.parse(in_progress_form.form_data)
              in_progress_form_data['toxic_exposure'] = {
                'conditions' => { 'arthritis' => true },
                'gulf_war_1990' => { 'iraq' => true }
              }
              in_progress_form.update!(form_data: in_progress_form_data.to_json)

              # Submit without any toxic exposure
              parsed_payload['form526'].delete('toxicExposure')

              expect(monitor).to receive(:track_toxic_exposure_changes)

              post('/v0/disability_compensation_form/submit_all_claim',
                   params: JSON.generate(parsed_payload),
                   headers:)
              expect(response).to have_http_status(:ok)
            end
          end

          context 'when toxic exposure is unchanged' do
            it 'does not log' do
              # Update InProgressForm with snake_case (Rails transforms save-in-progress to snake_case)
              in_progress_form = InProgressForm.form_for_user(FormProfiles::VA526ez::FORM_ID, user)
              in_progress_form_data = JSON.parse(in_progress_form.form_data)
              in_progress_form_data['toxic_exposure'] = {
                'conditions' => { 'arthritis' => true },
                'gulf_war_1990' => { 'iraq' => true }
              }
              in_progress_form.update!(form_data: in_progress_form_data.to_json)

              # Submit with same toxic exposure
              parsed_payload['form526']['toxicExposure'] = {
                'conditions' => { 'arthritis' => true },
                'gulfWar1990' => { 'iraq' => true }
              }

              # track_toxic_exposure_changes will still be called, but monitor.submit_event should not
              # (the method returns early if no changes)
              allow(monitor).to receive(:track_toxic_exposure_changes)
              expect(monitor).not_to receive(:submit_event)

              post('/v0/disability_compensation_form/submit_all_claim',
                   params: JSON.generate(parsed_payload),
                   headers:)
              expect(response).to have_http_status(:ok)
            end
          end

          context 'when no toxic exposure in InProgressForm' do
            it 'does not log' do
              # Update InProgressForm to have no toxic exposure (delete snake_case key)
              in_progress_form = InProgressForm.form_for_user(FormProfiles::VA526ez::FORM_ID, user)
              in_progress_form_data = JSON.parse(in_progress_form.form_data)
              in_progress_form_data.delete('toxic_exposure')
              in_progress_form_data.delete('toxicExposure') # Delete both just in case
              in_progress_form.update!(form_data: in_progress_form_data.to_json)

              allow(monitor).to receive(:track_toxic_exposure_changes)
              expect(monitor).not_to receive(:submit_event)

              post('/v0/disability_compensation_form/submit_all_claim',
                   params: all_claims_form,
                   headers:)
              expect(response).to have_http_status(:ok)
            end
          end

          context 'when flipper flag is disabled' do
            it 'does not call track_toxic_exposure_changes' do
              # Disable toxic exposure purge flag to prevent logging
              allow(Flipper).to receive(:enabled?)
                .with(:disability_526_toxic_exposure_opt_out_data_purge, anything)
                .and_return(false)

              expect(monitor).not_to receive(:track_toxic_exposure_changes)

              post('/v0/disability_compensation_form/submit_all_claim',
                   params: all_claims_form,
                   headers:)
              expect(response).to have_http_status(:ok)
            end
          end

          context 'when logging raises an error' do
            it 'does not fail the submission' do
              # Simulate an error in the logging method
              allow(monitor).to receive(:track_toxic_exposure_changes).and_raise(StandardError, 'Logging failed')

              # Expect the error to be logged
              expect(Rails.logger).to receive(:error).with(
                'Error logging toxic exposure changes',
                hash_including(
                  user_uuid: user.uuid,
                  error: 'Logging failed'
                )
              )

              # Submission should still succeed
              post('/v0/disability_compensation_form/submit_all_claim',
                   params: all_claims_form,
                   headers:)
              expect(response).to have_http_status(:ok)
            end
          end
        end

        describe 'toxic exposure allowlist integration test' do
          it 'does not filter out allowlisted toxic exposure tracking keys in the full end-to-end flow' do
            # Parse the payload
            parsed_payload = JSON.parse(all_claims_form)

            # Set up InProgressForm with toxic exposure data
            in_progress_form = InProgressForm.form_for_user(FormProfiles::VA526ez::FORM_ID, user)
            in_progress_form_data = JSON.parse(in_progress_form.form_data)
            in_progress_form_data['toxic_exposure'] = {
              'conditions' => { 'arthritis' => true },
              'gulf_war_1990' => { 'iraq' => true },
              'gulf_war_2001' => { 'djibouti' => true }
            }
            in_progress_form.update!(form_data: in_progress_form_data.to_json)

            # Submit with only gulfWar1990 (gulfWar2001 removed)
            parsed_payload['form526']['toxicExposure'] = {
              'conditions' => { 'arthritis' => true },
              'gulfWar1990' => { 'iraq' => true }
            }

            # Enable the flipper flag
            allow(Flipper).to receive(:enabled?)
              .with(:disability_526_toxic_exposure_opt_out_data_purge, anything)
              .and_return(true)

            # Capture all info log calls with their keyword arguments
            logged_calls = []
            allow(Rails.logger).to receive(:info) do |message, **kwargs|
              logged_calls << { message:, kwargs: }
            end

            post('/v0/disability_compensation_form/submit_all_claim',
                 params: JSON.generate(parsed_payload),
                 headers:)
            expect(response).to have_http_status(:ok)

            # Find the toxic exposure log call
            toxic_exposure_call = logged_calls.find do |call|
              call[:message].is_a?(String) && call[:message].include?('toxic exposure data purged')
            end

            # Verify the call was made
            expect(toxic_exposure_call).not_to be_nil

            # Get the context from the logged call
            context = toxic_exposure_call[:kwargs][:context]
            expect(context).not_to be_nil

            # Verify the context contains unfiltered values (not [FILTERED])
            expect(context[:submission_id]).to be_a(Integer)
            expect(context[:submission_id]).to be > 0
            expect(context[:completely_removed]).to be(false)
            expect(context[:removed_keys]).to eq(['gulfWar2001'])
            expect(context[:purge_reasons]).to be_a(Hash)
            expect(context[:conditions_state]).to be_a(String)
            expect(context[:orphaned_data_removed]).to be_in([true, false])
            expect(context[:tags]).to eq(['form_id:21-526EZ-ALLCLAIMS'])

            # Verify none of the values are filtered
            expect(context[:submission_id]).not_to eq('[FILTERED]')
            expect(context[:completely_removed]).not_to eq('[FILTERED]')
            expect(context[:removed_keys]).not_to eq('[FILTERED]')
            expect(context[:purge_reasons]).not_to eq('[FILTERED]')
            expect(context[:conditions_state]).not_to eq('[FILTERED]')
            expect(context[:orphaned_data_removed]).not_to eq('[FILTERED]')
            expect(context[:tags]).not_to eq('[FILTERED]')
          end
        end

        it 'matches the rated disabilities schema with camel-inflection' do
          post '/v0/disability_compensation_form/submit_all_claim', params: all_claims_form, headers: headers_with_camel
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('submit_disability_form')
        end

        it 'starts the submit job' do
          expect(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim).to receive(:perform_async).once
          post '/v0/disability_compensation_form/submit_all_claim', params: all_claims_form, headers:
        end
      end

      context 'with an `bdd` claim' do
        let(:bdd_form) { File.read 'spec/support/disability_compensation_form/submit_all_claim/bdd.json' }
        let(:user) do
          build(:disabilities_compensation_user, :with_terms_of_use_agreement, icn: '1012666073V986297',
                                                                               idme_uuid: SecureRandom.uuid)
        end

        before do
          allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
        end

        it 'matches the rated disabilities schema' do
          post('/v0/disability_compensation_form/submit_all_claim', params: bdd_form, headers:)
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('submit_disability_form')
        end

        it 'matches the rated disabilities schema with camel-inflection' do
          post '/v0/disability_compensation_form/submit_all_claim', params: bdd_form, headers: headers_with_camel
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('submit_disability_form')
        end
      end
    end

    context 'with invalid json body' do
      it 'returns a 422' do
        post('/v0/disability_compensation_form/submit_all_claim', params: { 'form526' => nil }.to_json, headers:)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns a 422 when no new or increase disabilities are submitted' do
        all_claims_form = File.read 'spec/support/disability_compensation_form/submit_all_claim/all.json'
        json_object = JSON.parse(all_claims_form)
        json_object['form526'].delete('newPrimaryDisabilities')
        json_object['form526'].delete('newSecondaryDisabilities')
        updated_form = JSON.generate(json_object)
        post('/v0/disability_compensation_form/submit_all_claim', params: updated_form, headers:)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'SavedClaim::DisabilityCompensation::Form526AllClaim save error logging' do
    let(:form_params) { File.read 'spec/support/disability_compensation_form/submit_all_claim/all.json' }
    let(:claim_with_save_error) do
      claim = SavedClaim::DisabilityCompensation::Form526AllClaim.new
      errors = ActiveModel::Errors.new(claim)
      errors.add(:form, 'Mock form validation error')
      allow(claim).to receive_messages(errors:, save: false)
      claim
    end
    let!(:in_progress_form) { create(:in_progress_form, form_id: FormProfiles::VA526ez::FORM_ID, user_uuid: user.uuid) }

    context 'when the disability_526_track_saved_claim_error Flipper is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:disability_526_track_saved_claim_error).and_return(true)
      end

      after do
        allow(Flipper).to receive(:enabled?).with(:disability_526_track_saved_claim_error).and_return(false)
      end

      context 'when the claim fails to save' do
        before do
          allow(SavedClaim::DisabilityCompensation::Form526AllClaim).to receive(:from_hash)
            .and_return(claim_with_save_error)
        end

        it 'logs save errors for the claim and still returns a 422' do
          expect_any_instance_of(DisabilityCompensation::Loggers::Monitor).to receive(:track_saved_claim_save_error)
            .with(
              claim_with_save_error.errors.errors,
              in_progress_form.id,
              user.uuid
            )

          post('/v0/disability_compensation_form/submit_all_claim', params: form_params, headers:)

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'when the claim saves successfully' do
        it 'does not track an error and returns a 200 response' do
          expect_any_instance_of(DisabilityCompensation::Loggers::Monitor)
            .not_to receive(:track_saved_claim_save_error)

          post('/v0/disability_compensation_form/submit_all_claim', params: form_params, headers:)
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when the disability_526_track_saved_claim_error Flipper is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:disability_526_track_saved_claim_error).and_return(false)
        allow(SavedClaim::DisabilityCompensation::Form526AllClaim).to receive(:from_hash)
          .and_return(claim_with_save_error)
      end

      it 'does not log save errors and still returns a 422' do
        expect_any_instance_of(DisabilityCompensation::Loggers::Monitor)
          .not_to receive(:track_saved_claim_save_error)

        post('/v0/disability_compensation_form/submit_all_claim', params: form_params, headers:)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'Get /v0/disability_compensation_form/submission_status' do
    context 'with a success status' do
      let(:submission) { create(:form526_submission, submitted_claim_id: 61_234_567) }
      let(:job_status) { create(:form526_job_status, form526_submission_id: submission.id) }
      let!(:ancillary_job_status) do
        create(:form526_job_status,
               form526_submission_id: submission.id,
               job_class: 'AncillaryForm')
      end

      it 'returns the job status and response', :aggregate_failures do
        get("/v0/disability_compensation_form/submission_status/#{job_status.job_id}", params: nil, headers:)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to match(
          'data' => {
            'id' => '',
            'type' => 'form526_job_statuses',
            'attributes' => {
              'claim_id' => 61_234_567,
              'job_id' => job_status.job_id,
              'submission_id' => submission.id,
              'status' => 'success',
              'ancillary_item_statuses' => [
                a_hash_including('id' => ancillary_job_status.id,
                                 'job_id' => ancillary_job_status.job_id,
                                 'job_class' => 'AncillaryForm',
                                 'status' => 'success',
                                 'error_class' => nil,
                                 'error_message' => nil,
                                 'updated_at' => ancillary_job_status.updated_at.iso8601(3))
              ]
            }
          }
        )
      end
    end

    context 'with a retryable_error status' do
      let(:submission) { create(:form526_submission) }
      let(:job_status) { create(:form526_job_status, :retryable_error, form526_submission_id: submission.id) }

      it 'returns the job status and response', :aggregate_failures do
        get("/v0/disability_compensation_form/submission_status/#{job_status.job_id}", params: nil, headers:)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to have_deep_attributes(
          'data' => {
            'id' => '',
            'type' => 'form526_job_statuses',
            'attributes' => {
              'claim_id' => nil,
              'job_id' => job_status.job_id,
              'submission_id' => submission.id,
              'status' => 'retryable_error',
              'ancillary_item_statuses' => []
            }
          }
        )
      end
    end

    context 'with a non_retryable_error status' do
      let(:submission) { create(:form526_submission) }
      let(:job_status) { create(:form526_job_status, :non_retryable_error, form526_submission_id: submission.id) }

      it 'returns the job status and response', :aggregate_failures do
        get("/v0/disability_compensation_form/submission_status/#{job_status.job_id}", params: nil, headers:)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to have_deep_attributes(
          'data' => {
            'id' => '',
            'type' => 'form526_job_statuses',
            'attributes' => {
              'claim_id' => nil,
              'job_id' => job_status.job_id,
              'submission_id' => submission.id,
              'status' => 'non_retryable_error',
              'ancillary_item_statuses' => []
            }
          }
        )
      end
    end

    context 'when no record is found' do
      it 'returns the async submit transaction status and response', :aggregate_failures do
        get('/v0/disability_compensation_form/submission_status/123', params: nil, headers:)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
