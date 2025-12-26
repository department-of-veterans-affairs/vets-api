# frozen_string_literal: true

require 'rails_helper'
require 'increase_compensation/benefits_intake/submit_claim_job'
require 'increase_compensation/monitor'
require 'support/controller_spec_helper'

MOCK_URL = 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf'

RSpec.describe IncreaseCompensation::V0::ClaimsController, type: :request do
  let(:monitor) { double('IncreaseCompensation::Monitor') }
  let(:user) { create(:user) }

  before do
    sign_in_as(user)
    allow(IncreaseCompensation::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive_messages(
      track_show404: nil,
      track_show_error: nil,
      track_create_attempt: nil,
      track_create_error: nil,
      track_create_success: nil,
      track_create_validation_error: nil,
      track_process_attachment_error: nil
    )
  end

  describe '#create' do
    let(:claim) { build(:increase_compensation_claim) }
    let(:param_name) { :increase_compensation_claim }
    let(:form_id) { '21-8940V1' }

    it 'logs validation errors' do
      allow(IncreaseCompensation::SavedClaim).to receive(:new).and_return(claim)
      allow(claim).to receive_messages(save: false, errors: 'mock error')

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_error).once
      expect(monitor).to receive(:track_create_validation_error).once
      expect(claim).not_to receive(:process_attachments!)
      expect(IncreaseCompensation::BenefitsIntake::SubmitClaimJob).not_to receive(:perform_async)

      post '/increase_compensation/v0/claims', params: { param_name => { form: claim.form } }

      expect(response).to have_http_status(:internal_server_error)
    end

    it('returns a serialized claim', skip: 'TODO after schema built') do
      allow(IncreaseCompensation::SavedClaim).to receive(:new).and_return(claim)

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_success).once
      expect(claim).to receive(:process_attachments!).once
      expect(IncreaseCompensation::BenefitsIntake::SubmitClaimJob).to receive(:perform_async)

      post '/increase_compensation/v0/claims', params: { param_name => { form: claim.form } }

      expect(response).to have_http_status(:success)
    end
  end

  describe '#show' do
    it 'logs an error if no claim found' do
      expect(monitor).to receive(:track_show404).once

      get '/increase_compensation/v0/claims/:id', params: { id: 'non-existant-saved-claim' }

      expect(response).to have_http_status(:not_found)
    end

    it 'logs an error' do
      error = StandardError.new('Mock Error')
      allow(IncreaseCompensation::SavedClaim).to receive(:find_by!).and_raise(error)

      expect(monitor).to receive(:track_show_error).once

      get '/increase_compensation/v0/claims/:id', params: { id: 'non-existant-saved-claim' }

      expect(response).to have_http_status(:internal_server_error)
    end

    it 'returns a serialized claim' do
      claim = build(:increase_compensation_claim)
      allow(IncreaseCompensation::SavedClaim).to receive(:find_by!).and_return(claim)
      mock_attempt = double('FormSubmissionEvent', created_at: Time.zone.now)
      allow_any_instance_of(PdfS3Operations)
        .to receive(:last_form_submission_attempt).and_return(mock_attempt)
      allow_any_instance_of(PdfS3Operations)
        .to receive(:s3_signed_url).and_return(MOCK_URL)

      get '/increase_compensation/v0/claims/:id', params: { id: 'increase_compensation_claim' }
      attributes = JSON.parse(response.body)['data']['attributes']

      expect(attributes['guid']).to eq(claim.guid)
      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq(claim.guid)
      expect(attributes['pdf_url']).to eq(MOCK_URL)
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#process_attachments' do
    let(:claim) { create(:increase_compensation_claim) }
    let(:in_progress_form) { build(:in_progress_form) }
    let(:bad_attachment) { PersistentAttachment.create!(saved_claim_id: claim.id) }
    let(:error) { StandardError.new('Something went wrong') }

    it 'returns a success', skip: 'TODO after schema built' do
      expect(claim).to receive(:process_attachments!)
      subject.send(:process_attachments, in_progress_form, claim)
    end

    it 'returns a failure', skip: 'TODO after schema built' do
      allow(claim).to receive(:process_attachments!).and_raise(error)

      expect do
        subject.send(:process_attachments!, in_progress_form, claim)
      end.to raise_error(StandardError, 'Something went wrong')
    end
  end

  describe '#log_validation_error_to_metadata' do
    let(:claim) { build(:increase_compensation_claim) }
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
