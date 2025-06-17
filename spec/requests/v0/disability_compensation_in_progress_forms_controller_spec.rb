# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require 'disability_compensation/factories/api_provider_factory'

# Because of the shared_example this is behaving like a controller and request spec
RSpec.describe V0::DisabilityCompensationInProgressFormsController do
  it_behaves_like 'a controller that does not log 404 to Sentry'

  context 'with a user' do
    let(:loa3_user) { build(:disabilities_compensation_user, :with_terms_of_use_agreement, uuid: SecureRandom.uuid) }
    let(:loa1_user) { build(:user, :loa1) }

    describe '#show' do
      before do
        allow(Flipper).to receive(:enabled?).with(:in_progress_form_custom_expiration)
        allow(Flipper).to receive(:enabled?).with(:disability_compensation_sync_modern_0781_flow, instance_of(User))
        allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User))
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

        let(:lighthouse_user) { build(:evss_user, uuid: SecureRandom.uuid) }

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
