# frozen_string_literal: true

require 'rails_helper'
require 'income_and_assets/benefits_intake/submit_claim_job'
require 'income_and_assets/monitor'
require 'support/controller_spec_helper'

RSpec.describe IncomeAndAssets::V0::ClaimsController, type: :request do
  let(:monitor) { double('IncomeAndAssets::Monitor') }
  let(:user) { create(:user) }

  before do
    sign_in_as(user)
    allow(IncomeAndAssets::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive_messages(track_show404: nil, track_show_error: nil, track_create_attempt: nil,
                                       track_create_error: nil, track_create_success: nil,
                                       track_create_validation_error: nil)
  end

  describe '#create' do
    let(:claim) { build(:income_and_assets_claim) }
    let(:param_name) { :income_and_assets_claim }
    let(:form_id) { '21P-0969' }

    it 'logs validation errors' do
      allow(IncomeAndAssets::SavedClaim).to receive(:new).and_return(claim)
      allow(claim).to receive_messages(save: false, errors: 'mock error')

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_error).once
      expect(monitor).to receive(:track_create_validation_error).once
      expect(IncomeAndAssets::BenefitsIntake::SubmitClaimJob).not_to receive(:perform_async)

      post '/income_and_assets/v0/claims', params: { param_name => { form: claim.form } }

      expect(response).to have_http_status(:internal_server_error)
    end

    it('returns a serialized claim') do
      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_success).once
      expect(IncomeAndAssets::BenefitsIntake::SubmitClaimJob).to receive(:perform_async)

      post '/income_and_assets/v0/claims', params: { param_name => { form: claim.form } }

      expect(response).to have_http_status(:success)
    end
  end

  describe '#show' do
    it 'logs an error if no claim found' do
      expect(monitor).to receive(:track_show404).once

      get '/income_and_assets/v0/claims/:id', params: { id: 'non-existant-saved-claim' }

      expect(response).to have_http_status(:not_found)
    end

    it 'logs an error' do
      error = StandardError.new('Mock Error')
      allow(IncomeAndAssets::SavedClaim).to receive(:find_by!).and_raise(error)

      expect(monitor).to receive(:track_show_error).once

      get '/income_and_assets/v0/claims/:id', params: { id: 'non-existant-saved-claim' }

      expect(response).to have_http_status(:internal_server_error)
    end

    it 'returns a serialized claim' do
      claim = build(:income_and_assets_claim)
      allow(IncomeAndAssets::SavedClaim).to receive(:find_by!).and_return(claim)

      get '/income_and_assets/v0/claims/:id', params: { id: 'income_and_assets_claim' }

      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq(claim.guid)
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#process_and_upload_to_lighthouse' do
    let(:claim) { build(:income_and_assets_claim) }
    let(:in_progress_form) { build(:in_progress_form) }

    it 'returns a success' do
      expect(claim).to receive(:process_attachments!)

      subject.send(:process_and_upload_to_lighthouse, in_progress_form, claim)
    end

    it 'raises an error' do
      allow(claim).to receive(:process_attachments!).and_raise(StandardError, 'mock error')
      expect(monitor).to receive(:track_process_attachment_error).once
      expect(IncomeAndAssets::BenefitsIntake::SubmitClaimJob).not_to receive(:perform_async)

      expect do
        subject.send(:process_and_upload_to_lighthouse, in_progress_form, claim)
      end.to raise_error(StandardError, 'mock error')
    end
  end

  describe '#log_validation_error_to_metadata' do
    let(:claim) { build(:income_and_assets_claim) }
    let(:in_progress_form) { build(:in_progress_form) }

    it 'returns if a `blank` in_progress_form' do
      ['', [], {}, nil].each do |blank|
        expect(in_progress_form).not_to receive(:update)
        result = subject.send(:log_validation_error_to_metadata, blank, claim)
        expect(result).to be_nil
      end
    end

    it 'updates the in_progress_form' do
      expect(in_progress_form).to receive(:metadata).and_return(in_progress_form.metadata)
      expect(in_progress_form).to receive(:update)
      subject.send(:log_validation_error_to_metadata, in_progress_form, claim)
    end
  end

  # end RSpec.describe
end
