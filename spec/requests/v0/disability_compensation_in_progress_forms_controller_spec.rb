# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require 'disability_compensation/factories/api_provider_factory'

# Because of the shared_example this is behaving like a controller and request spec
RSpec.describe V0::DisabilityCompensationInProgressFormsController do
  it_behaves_like 'a controller that does not log 404 to Sentry'

  context 'with a user' do
    let(:loa3_user) { build(:disabilities_compensation_user) }
    let(:loa1_user) { build(:user, :loa1) }

    describe '#show' do
      before do
        allow(Flipper).to receive(:enabled?).with(:disability_compensation_sync_modern_0781_flow, instance_of(User))
        allow(Flipper).to receive(:enabled?).with(:intent_to_file_lighthouse_enabled, instance_of(User))
      end

      context 'using the Lighthouse Rated Disabilities Provider' do
        let(:rated_disabilities_from_lighthouse) do
          [{ 'name' => 'Diabetes mellitus0',
             'ratedDisabilityId' => '1',
             'ratingDecisionId' => '0',
             'diagnosticCode' => 5238,
             'decisionCode' => 'SVCCONNCTED',
             'decisionText' => 'Service Connected',
             'ratingPercentage' => 50,
             'maximumRatingPercentage' => nil }]
        end

        let(:lighthouse_user) { build(:evss_user, icn: '123498767V234859') }

        let!(:in_progress_form_lighthouse) do
          form_json = JSON.parse(
            File.read(
              'spec/support/disability_compensation_form/' \
              '526_in_progress_form_minimal_lighthouse_rated_disabilities.json'
            )
          )
          create(:in_progress_form,
                 user_uuid: lighthouse_user.uuid,
                 form_id: '21-526EZ',
                 form_data: form_json['formData'],
                 metadata: form_json['metadata'])
        end

        before do
          allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('blahblech')

          sign_in_as(lighthouse_user)
        end

        context 'when a form is found and rated_disabilities have updates' do
          it 'returns the form as JSON' do
            # change form data
            fd = JSON.parse(in_progress_form_lighthouse.form_data)
            fd['ratedDisabilities'].first['diagnosticCode'] = '111'
            in_progress_form_lighthouse.update(form_data: fd)

            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              VCR.use_cassette('disability_max_ratings/max_ratings') do
                get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
              end
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            expect(json_response['formData']['ratedDisabilities'])
              .to eq(
                JSON.parse(in_progress_form_lighthouse.form_data)['ratedDisabilities']
              )
            expect(json_response['formData']['updatedRatedDisabilities']).to eq(rated_disabilities_from_lighthouse)
            expect(json_response['metadata']['returnUrl']).to eq('/disabilities/rated-disabilities')
          end

          it 'returns an unaltered form if Lighthouse returns an error' do
            rated_disabilities_before = JSON.parse(in_progress_form_lighthouse.form_data)['ratedDisabilities']
            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/503_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            expect(json_response['formData']['ratedDisabilities']).to eq(rated_disabilities_before)
            expect(json_response['formData']['updatedRatedDisabilities']).to be_nil
            expect(json_response['metadata']['returnUrl']).to eq('/va-employee')
          end
        end

        context 'when a form is found and rated_disabilities are unchanged' do
          it 'returns the form as JSON' do
            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            expect(json_response['formData']['ratedDisabilities'])
              .to eq(
                JSON.parse(in_progress_form_lighthouse.form_data)['ratedDisabilities']
              )

            expect(json_response['formData']['updatedRatedDisabilities']).to be_nil
            expect(json_response['metadata']['returnUrl']).to eq('/va-employee')
          end
        end

        context 'when toxic exposure' do
          it 'returns startedFormVersion as 2019 for existing InProgressForms' do
            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            expect(json_response['formData']['startedFormVersion']).to eq('2019')
          end
        end

        context 'prefills formData when user does not have an InProgressForm pending submission' do
          let(:user) { loa1_user }
          let!(:form_id) { '21-526EZ' }

          before do
            sign_in_as(user)
          end

          it 'adds default startedFormVersion for new InProgressForm' do
            get v0_disability_compensation_in_progress_form_url(form_id), params: nil
            json_response = JSON.parse(response.body)
            expect(json_response['formData']['startedFormVersion']).to eq('2022')
          end

          it 'returns 2022 when existing IPF with 2022 as startedFormVersion' do
            parsed_form_data = JSON.parse(in_progress_form_lighthouse.form_data)
            parsed_form_data['startedFormVersion'] = '2022'
            in_progress_form_lighthouse.form_data = parsed_form_data.to_json
            in_progress_form_lighthouse.save!
            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
              expect(response).to have_http_status(:ok)
              json_response = JSON.parse(response.body)
              expect(json_response['formData']['startedFormVersion']).to eq('2022')
            end
          end
        end

        context 'log_started_form_version logging' do
          it 'returns form data when startedFormVersion is present' do
            parsed_form_data = JSON.parse(in_progress_form_lighthouse.form_data)
            parsed_form_data['startedFormVersion'] = '2022'
            parsed_form_data.delete('started_form_version')
            in_progress_form_lighthouse.form_data = parsed_form_data.to_json
            in_progress_form_lighthouse.save!

            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            # With && logic, having just startedFormVersion is sufficient to preserve the value
            expect(json_response['formData']['startedFormVersion']).to eq('2022')
          end

          it 'sets default to 2019 when both startedFormVersion keys are missing from existing IPF' do
            # Remove both version keys to trigger the set_started_form_version path
            parsed_form_data = JSON.parse(in_progress_form_lighthouse.form_data)
            parsed_form_data.delete('startedFormVersion')
            parsed_form_data.delete('started_form_version')
            in_progress_form_lighthouse.form_data = parsed_form_data.to_json
            in_progress_form_lighthouse.save!

            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
            end

            # Request should still succeed and return the form with default 2019 version
            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            expect(json_response['formData']['startedFormVersion']).to eq('2019')
          end

          it 'does not break the response when logging succeeds' do
            parsed_form_data = JSON.parse(in_progress_form_lighthouse.form_data)
            parsed_form_data['startedFormVersion'] = '2019'
            in_progress_form_lighthouse.form_data = parsed_form_data.to_json
            in_progress_form_lighthouse.save!

            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            expect(json_response).to have_key('formData')
            expect(json_response).to have_key('metadata')
            expect(json_response['formData']['startedFormVersion']).to eq('2019')
          end

          it 'returns startedFormVersion 2022 for prefilled new InProgressForm' do
            sign_in_as(loa1_user)

            get v0_disability_compensation_in_progress_form_url('21-526EZ'), params: nil

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            expect(json_response['formData']['startedFormVersion']).to eq('2022')
          end

          it 'preserves existing startedFormVersion value' do
            parsed_form_data = JSON.parse(in_progress_form_lighthouse.form_data)
            parsed_form_data['startedFormVersion'] = '2019'
            in_progress_form_lighthouse.form_data = parsed_form_data.to_json
            in_progress_form_lighthouse.save!

            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            expect(json_response['formData']['startedFormVersion']).to eq('2019')
          end

          it 'preserves startedFormVersion when only started_form_version is present' do
            # Only set snake_case version
            parsed_form_data = JSON.parse(in_progress_form_lighthouse.form_data)
            parsed_form_data.delete('startedFormVersion')
            parsed_form_data['started_form_version'] = '2022'
            in_progress_form_lighthouse.form_data = parsed_form_data.to_json
            in_progress_form_lighthouse.save!

            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            # With && logic, having just started_form_version prevents default override
            expect(json_response['formData']['started_form_version']).to eq('2022')
          end
        end

        context 'set_started_form_version logic (&& not ||)' do
          it 'does NOT override when only camelCase startedFormVersion is present' do
            parsed_form_data = JSON.parse(in_progress_form_lighthouse.form_data)
            parsed_form_data['startedFormVersion'] = '2022'
            parsed_form_data.delete('started_form_version')
            in_progress_form_lighthouse.form_data = parsed_form_data.to_json
            in_progress_form_lighthouse.save!

            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            # Should preserve 2022 because && requires BOTH to be blank
            expect(json_response['formData']['startedFormVersion']).to eq('2022')
          end

          it 'does NOT override when only snake_case started_form_version is present' do
            parsed_form_data = JSON.parse(in_progress_form_lighthouse.form_data)
            parsed_form_data.delete('startedFormVersion')
            parsed_form_data['started_form_version'] = '2022'
            in_progress_form_lighthouse.form_data = parsed_form_data.to_json
            in_progress_form_lighthouse.save!

            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            # Should NOT add startedFormVersion = 2019 because started_form_version exists
            expect(json_response['formData']['startedFormVersion']).to be_nil
            expect(json_response['formData']['started_form_version']).to eq('2022')
          end

          it 'sets default 2019 ONLY when both keys are missing' do
            parsed_form_data = JSON.parse(in_progress_form_lighthouse.form_data)
            parsed_form_data.delete('startedFormVersion')
            parsed_form_data.delete('started_form_version')
            in_progress_form_lighthouse.form_data = parsed_form_data.to_json
            in_progress_form_lighthouse.save!

            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            # Should set default because BOTH are missing
            expect(json_response['formData']['startedFormVersion']).to eq('2019')
          end

          it 'preserves value when both keys are present' do
            parsed_form_data = JSON.parse(in_progress_form_lighthouse.form_data)
            parsed_form_data['startedFormVersion'] = '2022'
            parsed_form_data['started_form_version'] = '2022'
            in_progress_form_lighthouse.form_data = parsed_form_data.to_json
            in_progress_form_lighthouse.save!

            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            expect(json_response['formData']['startedFormVersion']).to eq('2022')
          end
        end

        context 'as_json optimization for updatedRatedDisabilities' do
          it 'returns correctly formatted updatedRatedDisabilities when disabilities change' do
            # Change form data to trigger the update path
            fd = JSON.parse(in_progress_form_lighthouse.form_data)
            fd['ratedDisabilities'].first['diagnosticCode'] = '111'
            in_progress_form_lighthouse.update(form_data: fd)

            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              VCR.use_cassette('disability_max_ratings/max_ratings') do
                get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
              end
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            updated_disabilities = json_response['formData']['updatedRatedDisabilities']

            # Verify the structure is correct (as_json produces same output as JSON.parse(to_json))
            expect(updated_disabilities).to be_an(Array)
            expect(updated_disabilities).not_to be_empty
            expect(updated_disabilities.first).to have_key('name')
            expect(updated_disabilities.first).to have_key('ratedDisabilityId')
            expect(updated_disabilities.first).to have_key('diagnosticCode')
          end

          it 'returns nil updatedRatedDisabilities when disabilities have not changed' do
            # Don't modify form data - disabilities should match
            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            expect(json_response['formData']['updatedRatedDisabilities']).to be_nil
          end

          it 'sets returnUrl when rated disabilities have updates and claimingIncrease is true' do
            fd = JSON.parse(in_progress_form_lighthouse.form_data)
            fd['ratedDisabilities'].first['diagnosticCode'] = '111'
            fd['view:claimType'] = { 'view:claimingIncrease' => true }
            in_progress_form_lighthouse.update(form_data: fd)

            VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
              VCR.use_cassette('disability_max_ratings/max_ratings') do
                get v0_disability_compensation_in_progress_form_url(in_progress_form_lighthouse.form_id), params: nil
              end
            end

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)
            expect(json_response['metadata']['returnUrl']).to eq('/disabilities/rated-disabilities')
          end
        end
      end

      describe '#update' do
        let(:update_user) { loa3_user }
        let(:new_form) { build(:in_progress_form, form_id: FormProfiles::VA526ez::FORM_ID) }
        let(:flipper0781) { :disability_compensation_sync_modern0781_flow_metadata }

        before do
          sign_in_as(update_user)
        end

        it 'inserts the form', run_at: '2017-01-01' do
          expect do
            put v0_disability_compensation_in_progress_form_url(new_form.form_id), params: {
              formData: new_form.form_data,
              metadata: new_form.metadata
            }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
          end.to change(InProgressForm, :count).by(1)
          expect(response).to have_http_status(:ok)
        end

        it 'adds 0781 metadata if flipper enabled' do
          allow(Flipper).to receive(:enabled?).with(flipper0781).and_return(true)
          put v0_in_progress_form_url(new_form.form_id),
              params: {
                form_data: { greeting: 'Hello!' },
                metadata: new_form.metadata
              }.to_json,
              headers: { 'CONTENT_TYPE' => 'application/json' }
          # Checking key present, it will be false regardless due to prefill not running
          expect(JSON.parse(response.body)['data']['attributes']['metadata'].key?('sync_modern0781_flow')).to be(true)
          expect(response).to have_http_status(:ok)
        end

        it 'does not add 0781 metadata if form and flipper disabled' do
          allow(Flipper).to receive(:enabled?).with(flipper0781).and_return(false)
          put v0_in_progress_form_url(new_form.form_id),
              params: {
                form_data: { greeting: 'Hello!' },
                metadata: new_form.metadata
              }.to_json,
              headers: { 'CONTENT_TYPE' => 'application/json' }
          expect(JSON.parse(response.body)['data']['attributes']['metadata'].key?('sync_modern0781_flow')).to be(false)
          expect(response).to have_http_status(:ok)
        end
      end

      context 'without a user' do
        describe '#show' do
          let(:in_progress_form) { create(:in_progress_form) }

          it 'returns a 401' do
            get v0_disability_compensation_in_progress_form_url(in_progress_form.form_id), params: nil

            expect(response).to have_http_status(:unauthorized)
          end
        end
      end
    end
  end
end
