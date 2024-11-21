# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require 'burials/monitor'

RSpec.describe V0::BurialClaimsController, type: :controller do
  let(:monitor) { double('Burials::Monitor') }

  before do
    allow(Burials::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive_messages(track_show404: nil, track_show_error: nil, track_create_attempt: nil,
                                       track_create_error: nil, track_create_success: nil,
                                       track_create_validation_error: nil, track_process_attachment_error: nil)
  end

  describe 'with a user' do
    let(:form) { build(:burial_claim) }
    let(:param_name) { :burial_claim }
    let(:form_id) { '21P-530EZ' }
    let(:user) { create(:user) }

    it 'logs validation errors' do
      allow(SavedClaim::Burial).to receive(:new).and_return(form)
      allow(form).to receive_messages(save: false, errors: 'mock error')

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_validation_error).once
      expect(monitor).to receive(:track_create_error).once
      expect(form).not_to receive(:process_attachments!)

      response = post(:create, params: { param_name => { form: form.form } })
      expect(response.status).to eq(500)
    end
  end

  describe '#show' do
    let(:claim) { build(:burial_claim) }

    it 'returns a success when the claim is found' do
      allow(SavedClaim::Burial).to receive(:find_by!).and_return(claim)
      response = get(:show, params: { id: claim.guid })

      expect(response.status).to eq(200)
    end

    it 'returns an error if the claim is not found' do
      expect(monitor).to receive(:track_show404).once

      response = get(:show, params: { id: 'non-existant-saved-claim' })

      expect(response.status).to eq(404)
    end

    it 'logs show errors' do
      error = StandardError.new('Mock Error')
      allow(SavedClaim::Burial).to receive(:find_by!).and_raise(error)

      expect(monitor).to receive(:track_show_error).once

      response = get(:show, params: { id: 'non-existant-saved-claim' })

      expect(response.status).to eq(500)
    end
  end

  describe '#process_and_upload_to_lighthouse' do
    let(:claim) { build(:burial_claim_v2) }
    let(:in_progress_form) { build(:in_progress_form) }

    it 'returns a success' do
      expect(claim).to receive(:process_attachments!)

      subject.send(:process_and_upload_to_lighthouse, in_progress_form, claim)
    end

    it 'raises an error' do
      allow(claim).to receive(:process_attachments!).and_raise(StandardError, 'mock error')
      expect(monitor).to receive(:track_process_attachment_error).once
      expect(Pensions::PensionBenefitIntakeJob).not_to receive(:perform_async)

      expect do
        subject.send(:process_and_upload_to_lighthouse, in_progress_form, claim)
      end.to raise_error(StandardError, 'mock error')
    end
  end

  describe '#log_validation_error_to_metadata' do
    let(:claim) { build(:burial_claim) }
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
