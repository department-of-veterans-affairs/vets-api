# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::DisabilityCompensationInProgressFormsController, type: :request do
  it_behaves_like 'a controller that does not log 404 to Sentry'

  context 'with a user' do
    let(:loa3_user) { build(:disabilities_compensation_user) }
    let(:loa1_user) { build(:user, :loa1) }

    before do
      sign_in_as(user)
    end

    describe '#show' do
      let(:user) { loa3_user }
      let!(:in_progress_form) do
        form_json = JSON.parse(File.read('spec/support/disability_compensation_form/526_in_progress_form_maixmal.json'))
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

      context 'when a form is found' do
        it 'returns the form as JSON' do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
            get v0_disability_compensation_in_progress_form_url(in_progress_form.form_id), params: nil
          end
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(
            'formData' => JSON.parse(in_progress_form.form_data),
            'metadata' => in_progress_form.metadata
          )
        end
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
