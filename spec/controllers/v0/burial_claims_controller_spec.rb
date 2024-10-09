# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../lib/burials/monitor'

RSpec.describe V0::BurialClaimsController, type: :controller do
  let(:monitor) { double('Burials::Monitor') }

  before do
    Flipper.enable(:va_burial_v2)
    allow(Burials::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive_messages(track_show404: nil, track_show_error: nil, track_create_attempt: nil,
                                       track_create_error: nil, track_create_success: nil,
                                       track_create_validation_error: nil)
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
        expect(monitor).to receive(:track_create_attempt).once
        expect(monitor).to receive(:track_create_success).once
        expect(controller).to receive(:clear_saved_form).with(form_id).and_call_original
        sign_in_as(user)
        expect { send_create }.to change(InProgressForm, :count).by(-1)
      end
    end

    it 'logs validation errors' do
      allow(SavedClaim::Burial).to receive(:new).and_return(form)
      allow(form).to receive_messages(save: false, errors: 'mock error')

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_validation_error).once
      expect(monitor).to receive(:track_create_error).once
      expect(form).not_to receive(:submit_to_structured_data_services!)

      response = send_create
      expect(response.status).to eq(500)
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
      expect(monitor).to receive(:track_show404).once

      get(:show, params: { id: '12345' })

      expect(response).to have_http_status(:not_found)
    end

    it 'logs show errors' do
      allow(SavedClaim::Burial).to receive(:find_by).and_raise(StandardError, 'mock error')
      expect(monitor).to receive(:track_show_error).once

      get(:show, params: { id: '12345' })

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe '#log_validation_error_to_metadata' do
    let(:claim) { build(:burial_claim_v2) }
    let(:in_progress_form) { build(:in_progress_form) }

    it 'returns if a `blank` in_progress_form' do
      ['', [], {}, nil].each do |blank|
        expect(in_progress_form).not_to receive(:update)
        result = subject.send(:log_validation_error_to_metadata, blank, claim)
        expect(result).to eq(nil)
      end
    end

    it 'updates the in_progress_form' do
      expect(in_progress_form).to receive(:metadata).and_return(in_progress_form.metadata)
      expect(in_progress_form).to receive(:update)
      subject.send(:log_validation_error_to_metadata, in_progress_form, claim)
    end
  end
end
