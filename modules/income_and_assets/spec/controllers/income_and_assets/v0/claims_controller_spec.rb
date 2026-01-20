# frozen_string_literal: true

require 'rails_helper'
require 'income_and_assets/benefits_intake/submit_claim_job'
require 'income_and_assets/monitor'
require 'support/controller_spec_helper'
require 'bpds/sidekiq/submit_to_bpds_job'

RSpec.describe IncomeAndAssets::V0::ClaimsController, type: :request do
  let(:monitor) { double('IncomeAndAssets::Monitor') }
  let(:user) { create(:user) }

  before do
    sign_in_as(user)
    allow(IncomeAndAssets::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive_messages(track_show404: nil, track_show_error: nil, track_create_attempt: nil,
                                       track_create_error: nil, track_create_success: nil,
                                       track_create_validation_error: nil, track_process_attachment_error: nil)
  end

  describe '#create' do
    let(:claim) { build(:income_and_assets_claim) }
    let(:param_name) { :income_and_assets_claim }
    let(:form_id) { '21P-0969' }

    before do
      allow(Flipper).to receive(:enabled?).with(:income_and_assets_bpds_service_enabled).and_return(false)
    end

    it 'logs validation errors' do
      allow(IncomeAndAssets::SavedClaim).to receive(:new).and_return(claim)
      allow(claim).to receive_messages(save: false, errors: 'mock error')

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_error).once
      expect(monitor).to receive(:track_create_validation_error).once
      expect(claim).not_to receive(:process_attachments!)
      expect(IncomeAndAssets::BenefitsIntake::SubmitClaimJob).not_to receive(:perform_async)

      post '/income_and_assets/v0/claims', params: { param_name => { form: claim.form } }

      expect(response).to have_http_status(:internal_server_error)
    end

    it('returns a serialized claim') do
      allow(IncomeAndAssets::SavedClaim).to receive(:new).and_return(claim)

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_success).once
      expect(claim).to receive(:process_attachments!).once
      expect(IncomeAndAssets::BenefitsIntake::SubmitClaimJob).to receive(:perform_async)

      post '/income_and_assets/v0/claims', params: { param_name => { form: claim.form } }

      expect(response).to have_http_status(:success)
    end

    context 'when income_and_assets_bpds_service_enabled flag is enabled' do
      let(:user) { create(:user, :loa3) }
      let(:claim) { build(:income_and_assets_claim, id: 79) }
      let(:mpi_profile) { build(:mpi_profile) }
      let(:mpi_response) { build(:find_profile_response, profile: mpi_profile) }
      let(:participant_id) { mpi_profile.participant_id }
      let(:encrypted_payload) { KmsEncrypted::Box.new.encrypt({ participant_id: }.to_json) }

      before do
        allow(Flipper).to receive(:enabled?).with(:income_and_assets_bpds_service_enabled).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:bpds_service_enabled).and_return(true)
        allow(BPDS::Sidekiq::SubmitToBPDSJob).to receive(:perform_async)
        allow(IncomeAndAssets::SavedClaim).to receive(:new).and_return(claim)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier)
          .with(identifier: user.icn, identifier_type: MPI::Constants::ICN)
          .and_return(mpi_response)
      end

      it 'submits to BPDS with participant_id from MPI' do
        expect(BPDS::Sidekiq::SubmitToBPDSJob).to receive(:perform_async).with(claim.id, encrypted_payload)

        post '/income_and_assets/v0/claims', params: { param_name => { form: claim.form } }

        expect(response).to have_http_status(:success)
      end
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

  describe '#process_attachments' do
    let(:claim) { create(:income_and_assets_claim) }
    let(:in_progress_form) { build(:in_progress_form) }
    let(:bad_attachment) { PersistentAttachment.create!(saved_claim_id: claim.id) }
    let(:error) { StandardError.new('Something went wrong') }

    before do
      form_data = {
        files: [{ 'confirmationCode' => bad_attachment.guid }]
      }
      in_progress_form.update!(form_data: form_data.to_json)

      allow(claim).to receive_messages(
        attachment_keys: [:files],
        open_struct_form: OpenStruct.new(files: [OpenStruct.new(confirmationCode: bad_attachment.guid)])
      )
      allow_any_instance_of(PersistentAttachment).to receive(:file_data).and_raise(error)
      allow(Flipper).to receive(:enabled?)
                    .with(:income_and_assets_persistent_attachment_error_email_notification).and_return(true)
    end

    it 'removes bad attachments, updates the in_progress_form, and destroys the claim if all attachments are bad' do
      allow(claim).to receive(:process_attachments!).and_raise(error)
      expect(claim).to receive(:send_email).with(:persistent_attachment_error)

      aggregate_failures do
        expect do
          subject.send(:process_attachments, in_progress_form, claim)
        rescue
          # Swallow error to test side effects
        end.to change { PersistentAttachment.where(id: bad_attachment.id).count }
          .from(1).to(0)
          .and change { IncomeAndAssets::SavedClaim.where(id: claim.id).count }
          .from(1).to(0)
      end

      expect(monitor).to have_received(:track_process_attachment_error).with(in_progress_form, claim, anything)
      expect(JSON.parse(in_progress_form.reload.form_data)['files']).to be_empty
    end

    it 'returns a success' do
      expect(claim).to receive(:process_attachments!)

      subject.send(:process_attachments, in_progress_form, claim)
    end

    it 'sets the user account on the claim' do
      allow(IncomeAndAssets::SavedClaim).to receive(:new).and_call_original
      post '/income_and_assets/v0/claims', params: { income_and_assets_claim: { form: claim.form } }
      created_claim = IncomeAndAssets::SavedClaim.last
      expect(created_claim.user_account).to eq(user.user_account)
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
