# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require 'disability_compensation/factories/api_provider_factory'

RSpec.describe V0::DisabilityCompensationInProgressFormsController do
  it_behaves_like 'a controller that does not log 404 to Sentry'

  context 'with a user' do
    let(:loa3_user) { build(:disabilities_compensation_user) }
    let(:loa1_user) { build(:user, :loa1) }

    before do
      Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES)
      sign_in_as(user)
    end

    describe '#show' do
      let(:user) { loa3_user }
      let(:rated_disabilites_from_evss) do
        [{ 'name' => 'Diabetes mellitus0',
           'ratedDisabilityId' => '0',
           'ratingDecisionId' => '63655',
           'diagnosticCode' => 5238,
           'decisionCode' => 'SVCCONNCTED',
           'decisionText' => 'Service Connected',
           'ratingPercentage' => 100 },
         { 'name' => 'Diabetes mellitus1',
           'ratedDisabilityId' => '1',
           'ratingDecisionId' => '63655',
           'diagnosticCode' => 5238,
           'decisionCode' => 'SVCCONNCTED',
           'decisionText' => 'Service Connected',
           'ratingPercentage' => 100 }]
      end
      let!(:in_progress_form) do
        form_json = JSON.parse(File.read('spec/support/disability_compensation_form/526_in_progress_form_minimal.json'))
        FactoryBot.create(:in_progress_form,
                          user_uuid: user.uuid,
                          form_id: '21-526EZ',
                          form_data: form_json['formData'],
                          metadata: form_json['metadata'])
      end

      context 'when the user is not loa3' do
        let(:user) { loa1_user }

        it 'returns a 200' do
          get v0_disability_compensation_in_progress_form_url(in_progress_form.form_id), params: nil
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when a form is found and rated_disabilites have updates' do
        it 'returns the form as JSON' do
          # change form data
          fd = JSON.parse(in_progress_form.form_data)
          fd['ratedDisabilities'].first['diagnosticCode'] = '111'
          in_progress_form.update(form_data: fd)

          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
            get v0_disability_compensation_in_progress_form_url(in_progress_form.form_id), params: nil
          end
          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response['formData']['ratedDisabilities']).to eq(
            JSON.parse(in_progress_form.form_data)['ratedDisabilities']
          )
          expect(json_response['formData']['updatedRatedDisabilities']).to eq(rated_disabilites_from_evss)
          expect(json_response['metadata']['returnUrl']).to eq('/disabilities/rated-disabilities')
        end

        it 'returns an unaltered form if EVSS does not respond' do
          rated_disabilities_before = JSON.parse(in_progress_form.form_data)['ratedDisabilities']
          allow_any_instance_of(EVSS::DisabilityCompensationForm::Service).to(
            receive(:get_rated_disabilities).and_raise(Common::Client::Errors::ClientError)
          )
          get v0_disability_compensation_in_progress_form_url(in_progress_form.form_id), params: nil

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response['formData']['ratedDisabilities']).to eq(rated_disabilities_before)
          expect(json_response['formData']['updatedRatedDisabilities']).to be_nil
          expect(json_response['metadata']['returnUrl']).to eq('/va-employee')
        end
      end

      context 'when a form is found and rated_disabilites are unchanged' do
        it 'returns the form as JSON' do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
            get v0_disability_compensation_in_progress_form_url(in_progress_form.form_id), params: nil
          end

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response['formData']['ratedDisabilities']).to eq(
            JSON.parse(in_progress_form.form_data)['ratedDisabilities']
          )
          expect(json_response['formData']['updatedRatedDisabilities']).to be_nil
          expect(json_response['metadata']['returnUrl']).to eq('/va-employee')
        end
      end
    end

    describe '#index' do
      subject do
        get v0_disability_compensation_in_progress_forms_url, params: nil
      end

      let(:user) { loa3_user }

      it 'returns a 200' do
        subject
        expect(response).to have_http_status(:ok)
      end
    end

    describe '#update' do
      let(:user) { loa3_user }
      let(:new_form) { FactoryBot.build(:in_progress_form, user_uuid: user.uuid) }

      it 'inserts the form', run_at: '2017-01-01' do
        expect do
          put v0_disability_compensation_in_progress_form_url(new_form.form_id), params: {
            formData: new_form.form_data,
            metadata: new_form.metadata
          }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
        end.to change(InProgressForm, :count).by(1)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  context 'without a user' do
    describe '#show' do
      let(:in_progress_form) { FactoryBot.create(:in_progress_form) }

      it 'returns a 401' do
        get v0_disability_compensation_in_progress_form_url(in_progress_form.form_id), params: nil

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
