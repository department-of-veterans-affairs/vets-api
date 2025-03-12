# frozen_string_literal: true

require 'rails_helper'
require 'burials/monitor'
require 'support/controller_spec_helper'

RSpec.describe Burials::V0::ClaimsController, type: :request do
  let(:monitor) { double('Burials::Monitor') }

  before do
    allow(Burials::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive_messages(track_show404: nil, track_show_error: nil, track_create_attempt: nil,
                                       track_create_error: nil, track_create_success: nil,
                                       track_create_validation_error: nil, track_process_attachment_error: nil)
  end

  context 'with a user' do
    let(:form) { build(:burials_saved_claim) }
    let(:param_name) { :burial_claim }
    let(:form_id) { '21P-530EZ' }
    let(:user) { create(:user) }

    it 'logs validation errors' do
      allow(Burials::SavedClaim).to receive(:new).and_return(form)
      allow(form).to receive_messages(save: false, errors: 'mock error')

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_validation_error).once
      expect(monitor).to receive(:track_create_error).once
      expect(form).not_to receive(:process_attachments!)

      post '/burials/v0/claims', params: { param_name => { form: form.form } }

      expect(response).to have_http_status(:internal_server_error)
    end

    it 'passes successfully' do
      allow(Burials::SavedClaim).to receive(:new).and_return(form)

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_success).once
      expect(form).to receive(:process_attachments!)

      post '/burials/v0/claims', params: { param_name => { form: form.form } }

      expect(response).to have_http_status(:success)
    end
  end

  describe '#show' do
    let(:claim) { build(:burials_saved_claim) }

    it 'returns a success when the claim is found' do
      allow(Burials::SavedClaim).to receive(:find_by!).and_return(claim)

      get '/burials/v0/claims/:id', params: { id: claim.guid }

      expect(response).to have_http_status(:ok)
    end

    it 'returns an error if the claim is not found' do
      expect(monitor).to receive(:track_show404).once

      get '/burials/v0/claims/:id', params: { id: 'non-existant-saved-claim' }

      expect(response).to have_http_status(:not_found)
    end

    it 'logs show errors' do
      error = StandardError.new('Mock Error')
      allow(Burials::SavedClaim).to receive(:find_by!).and_raise(error)

      expect(monitor).to receive(:track_show_error).once

      get '/burials/v0/claims/:id', params: { id: 'non-existant-saved-claim' }

      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe '#process_and_upload_to_lighthouse' do
    let(:claim) { build(:burials_saved_claim) }
    let(:in_progress_form) { build(:in_progress_form) }
    let(:error) { StandardError.new('Something went wrong') }

    it 'returns a success' do
      expect(claim).to receive(:process_attachments!)

      subject.send(:process_and_upload_to_lighthouse, in_progress_form, claim)
    end

    it 'returns a failure' do
      allow(claim).to receive(:process_attachments!).and_raise(error)

      expect do
        subject.send(:process_and_upload_to_lighthouse, in_progress_form, claim)
      end.to raise_error(StandardError, 'Something went wrong')

      expect(monitor).to have_received(:track_process_attachment_error).with(in_progress_form, claim, anything)
    end
  end

  describe '#log_validation_error_to_metadata' do
    let(:claim) { build(:burials_saved_claim) }
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
end
