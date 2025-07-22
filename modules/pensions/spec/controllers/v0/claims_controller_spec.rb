# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require 'pensions/benefits_intake/submit_claim_job'
require 'kafka/sidekiq/event_bus_submission_job'
require 'bpds/sidekiq/submit_to_bpds_job'
require 'bpds/monitor'
require 'bpds/submission'

RSpec.describe Pensions::V0::ClaimsController, type: :controller do
  routes { Pensions::Engine.routes }

  let(:monitor) { double('Pensions::Monitor') }

  before do
    allow(Flipper).to receive(:enabled?).with(:pension_kafka_event_bus_submission_enabled).and_return(true)
    allow(Pensions::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive_messages(track_show404: nil, track_show_error: nil, track_create_attempt: nil,
                                       track_create_error: nil, track_create_success: nil,
                                       track_create_validation_error: nil, track_process_attachment_error: nil)
  end

  it_behaves_like 'a controller that deletes an InProgressForm', 'pension_claim', 'pensions_saved_claim',
                  '21P-527EZ'

  describe '#create' do
    let(:claim) { build(:pensions_saved_claim) }
    let(:param_name) { :pension_claim }
    let(:form_id) { '21P-527EZ' }
    let(:user) { create(:user) }

    it 'logs validation errors' do
      allow(Pensions::SavedClaim).to receive(:new).and_return(claim)
      allow(claim).to receive_messages(save: false, errors: 'mock error')

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_validation_error).once
      expect(monitor).to receive(:track_create_error).once
      expect(claim).not_to receive(:process_attachments!)
      expect(Pensions::BenefitsIntake::SubmitClaimJob).not_to receive(:perform_async)
      expect(Kafka::EventBusSubmissionJob).not_to receive(:perform_async)

      response = post(:create, params: { param_name => { form: claim.form } })

      expect(response.status).to eq(500)
    end

    it('returns a serialized claim') do
      allow(Pensions::SavedClaim).to receive(:new).and_return(claim)

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_success).once
      expect(claim).to receive(:process_attachments!).once
      expect(Pensions::BenefitsIntake::SubmitClaimJob).to receive(:perform_async).once

      response = post(:create, params: { param_name => { form: claim.form } })

      expect(response).to have_http_status(:success)
    end
  end

  describe '#show' do
    it 'logs an error if no claim found' do
      expect(monitor).to receive(:track_show404).once

      response = get(:show, params: { id: 'non-existant-saved-claim' })

      expect(response.status).to eq(404)
    end

    it 'logs an error' do
      error = StandardError.new('Mock Error')
      allow(Pensions::SavedClaim).to receive(:find_by!).and_raise(error)

      expect(monitor).to receive(:track_show_error).once

      response = get(:show, params: { id: 'non-existant-saved-claim' })

      expect(response.status).to eq(500)
    end

    it 'returns a serialized claim' do
      claim = build(:pensions_saved_claim)
      allow(Pensions::SavedClaim).to receive(:find_by!).and_return(claim)

      response = get(:show, params: { id: 'pensions_saved_claim' })

      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq(claim.guid)
      expect(response.status).to eq(200)
    end
  end

  describe '#process_attachments' do
    let(:claim) { create(:pensions_saved_claim) }
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
                    .with(:pension_persistent_attachment_error_email_notification).and_return(true)
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
          .and change { Pensions::SavedClaim.where(id: claim.id).count }
          .from(1).to(0)
      end

      expect(monitor).to have_received(:track_process_attachment_error).with(in_progress_form, claim, anything)
      expect(JSON.parse(in_progress_form.reload.form_data)['files']).to be_empty
    end

    it 'returns a success' do
      expect(claim).to receive(:process_attachments!)

      subject.send(:process_attachments, in_progress_form, claim)
    end
  end

  describe '#process_and_upload_to_bpds' do
    let(:claim) { build(:pensions_saved_claim) }
    let(:in_progress_form) { build(:in_progress_form) }
    let(:bpds_submission) { double('BPDS::Submission', id: '12345') }
    let(:bpds_monitor) { double('BPDS::Monitor') }
    let(:current_user) { create(:user) }
    let(:participant_id) { mpi_profile.participant_id }
    let(:encrypted_payload) { KmsEncrypted::Box.new.encrypt({ participant_id: }.to_json) }
    let(:mpi_profile) { build(:mpi_profile) }
    let(:mpi_response) { build(:find_profile_response, profile: mpi_profile) }

    before do
      allow(BPDS::Monitor).to receive(:new).and_return(bpds_monitor)
      allow(bpds_monitor).to receive(:track_submit_begun)
      allow(bpds_monitor).to receive(:track_get_user_identifier)
      allow(bpds_monitor).to receive(:track_get_user_identifier_result)
      allow(bpds_monitor).to receive(:track_get_user_identifier_file_number_result)
      allow(bpds_monitor).to receive(:track_skip_bpds_job)
      allow(BPDS::Submission).to receive(:create).and_return(bpds_submission)
      allow(BPDS::Sidekiq::SubmitToBPDSJob).to receive(:perform_async)
    end

    context 'when the user is LOA3' do
      let!(:user) { create(:user, :loa3) }

      it 'tracks the submission and enqueues the job' do
        allow(subject).to receive(:current_user).and_return(user) # rubocop:disable RSpec/SubjectStub

        expect(bpds_monitor).to receive(:track_get_user_identifier).with('loa3').once
        expect(bpds_monitor).to receive(:track_get_user_identifier_result).with('mpi', true).once
        expect(bpds_monitor).not_to receive(:track_get_user_identifier_file_number_result)
        expect(bpds_monitor).to receive(:track_submit_begun).with(claim.id).once
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier)
          .with(identifier: user.icn, identifier_type: MPI::Constants::ICN)
          .and_return(mpi_response)
        expect(BPDS::Sidekiq::SubmitToBPDSJob).to receive(:perform_async).with(claim.id, encrypted_payload).once

        subject.send(:process_and_upload_to_bpds, claim)
      end
    end

    context 'when the user is LOA1 and participant_id is present' do
      let!(:user) { create(:user, :loa1) }
      let(:encrypted_payload_bgs) { KmsEncrypted::Box.new.encrypt({ participant_id: '1234567890' }.to_json) }
      let(:bgs_response) { BGS::People::Response.new({ ptcpnt_id: '1234567890' }) }

      it 'tracks the submission and enqueues the job' do
        allow(subject).to receive(:current_user).and_return(user) # rubocop:disable RSpec/SubjectStub

        expect(bpds_monitor).to receive(:track_get_user_identifier).with('loa1').once
        expect(bpds_monitor).to receive(:track_get_user_identifier_result).with('bgs', true).once
        expect(bpds_monitor).not_to receive(:track_get_user_identifier_file_number_result)
        expect(bpds_monitor).to receive(:track_submit_begun).with(claim.id).once
        expect_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id).with(user:)
                                                                                               .and_return(bgs_response)
        expect(BPDS::Sidekiq::SubmitToBPDSJob).to receive(:perform_async).with(claim.id, encrypted_payload_bgs).once

        subject.send(:process_and_upload_to_bpds, claim)
      end
    end

    context 'when the user is LOA1 and participant_id is not present but file number is present' do
      let!(:user) { create(:user, :loa1) }
      let(:encrypted_payload_bgs) { KmsEncrypted::Box.new.encrypt({ file_number: '1234567890' }.to_json) }
      let(:bgs_response) { BGS::People::Response.new({ file_nbr: '1234567890' }) }

      it 'tracks the submission and enqueues the job' do
        allow(subject).to receive(:current_user).and_return(user) # rubocop:disable RSpec/SubjectStub

        expect(bpds_monitor).to receive(:track_get_user_identifier).with('loa1').once
        expect(bpds_monitor).to receive(:track_get_user_identifier_result).with('bgs', false).once
        expect(bpds_monitor).to receive(:track_get_user_identifier_file_number_result).with(true).once
        expect(bpds_monitor).to receive(:track_submit_begun).with(claim.id).once
        expect_any_instance_of(BGS::People::Request).to receive(:find_person_by_participant_id).with(user:)
                                                                                               .and_return(bgs_response)
        expect(BPDS::Sidekiq::SubmitToBPDSJob).to receive(:perform_async).with(claim.id, encrypted_payload_bgs).once

        subject.send(:process_and_upload_to_bpds, claim)
      end
    end

    context 'when the user is not authenticated and no identifier is available' do
      it 'tracks the submission and does not enqueue the job' do
        allow(subject).to receive(:current_user).and_return(nil) # rubocop:disable RSpec/SubjectStub

        expect(bpds_monitor).to receive(:track_get_user_identifier).with('unauthenticated').once
        expect(bpds_monitor).to receive(:track_skip_bpds_job).with(claim.id).once
        expect(bpds_monitor).not_to receive(:track_get_user_identifier_result)
        expect(bpds_monitor).not_to receive(:track_get_user_identifier_result_file_number)
        expect(bpds_monitor).not_to receive(:track_submit_begun)
        expect_any_instance_of(BGS::People::Request).not_to receive(:find_person_by_participant_id)
        expect(BPDS::Sidekiq::SubmitToBPDSJob).not_to receive(:perform_async)

        subject.send(:process_and_upload_to_bpds, claim)
      end
    end
  end

  describe '#submit_traceability_to_event_bus' do
    let(:claim) { build(:pensions_saved_claim) }

    it 'returns a success' do
      expect(Kafka::EventBusSubmissionJob).to receive(:perform_async)

      subject.send(:submit_traceability_to_event_bus, claim)
    end
  end

  describe '#log_validation_error_to_metadata' do
    let(:claim) { build(:pensions_saved_claim) }
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
