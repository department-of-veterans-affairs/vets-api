# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::BurialClaimsController, type: :controller do
  before do
    Flipper.enable(:va_burial_v2)
  end

  describe 'with a user' do
    let(:form) { build(:burial_claim_v2) }
    let(:param_name) { :burial_claim }
    let(:form_id) { '21P-530V2' }
    let(:user) { create(:user) }

    def send_create
      post(:create, params: { param_name => { form: form.form } })
    end

    it 'deletes the "in progress form"', run_at: 'Thu, 29 Aug 2019 17:45:03 GMT' do
      allow(SecureRandom).to receive(:uuid).and_return('c3fa0769-70cb-419a-b3a6-d2563e7b8502')

      VCR.use_cassette(
        'mvi/find_candidate/find_profile_with_attributes',
        VCR::MATCH_EVERYTHING
      ) do
        create(:in_progress_form, user_uuid: user.uuid, form_id:)
        expect(controller).to receive(:clear_saved_form).with(form_id).and_call_original
        sign_in_as(user)
        expect { send_create }.to change(InProgressForm, :count).by(-1)
      end
    end
  end

  describe '#show' do
    it 'returns the submission status when the claim uses central mail' do
      claim = create(:burial_claim_v2)
      claim.central_mail_submission.update!(state: 'success')
      get(:show, params: { id: claim.guid })

      expect(JSON.parse(response.body)['data']['attributes']['state']).to eq('success')
    end

    it 'returns the submission status when the claim uses benefits intake' do
      claim = create(:burial_claim_v2)
      claim.form_submissions << create(:form_submission, :pending, form_type: '21P-530V2')
      get(:show, params: { id: claim.guid })

      expect(JSON.parse(response.body)['data']['attributes']['state']).to eq('success')
    end

    it 'returns an error if the claim is not found' do
      get(:show, params: { id: '12345' })
      expect(response).to have_http_status(:not_found)
    end
  end
end
