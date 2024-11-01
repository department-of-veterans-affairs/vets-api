# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe DecisionReview::FailureNotificationEmailJob, type: :job do
  subject { described_class }

  around do |example|
    Sidekiq::Testing.inline!(&example)
  end

  let(:guid1) { SecureRandom.uuid }
  let(:guid2) { SecureRandom.uuid }
  let(:guid3) { SecureRandom.uuid }
  let(:guid4) { SecureRandom.uuid }

  let(:notification_id) { SecureRandom.uuid }
  let(:notification_id2) { SecureRandom.uuid }
  let(:vanotify_service) do
    service = instance_double(VaNotify::Service)

    response = instance_double(Notifications::Client::ResponseNotification, id: notification_id)
    response2 = instance_double(Notifications::Client::ResponseNotification, id: notification_id2)
    allow(service).to receive(:send_email).and_return(response, response2)

    service
  end

  let(:user_uuid) { create(:user, :loa3, ssn: '212222112').uuid }
  let(:user_uuid2) { create(:user, :loa3, uuid: SecureRandom.uuid, ssn: '412222112').uuid }

  let(:mpi_profile) { build(:mpi_profile, vet360_id: Faker::Number.number) }
  let(:mpi_profile2) { build(:mpi_profile, vet360_id: Faker::Number.number) }
  let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
  let(:find_profile_response2) { create(:find_profile_response, profile: mpi_profile2) }
  let(:mpi_service) do
    service = instance_double(MPI::Service, find_profile_by_identifier: nil)
    allow(service).to receive(:find_profile_by_identifier).with(identifier: user_uuid, identifier_type: anything)
                                                          .and_return(find_profile_response)
    allow(service).to receive(:find_profile_by_identifier).with(identifier: user_uuid2, identifier_type: anything)
                                                          .and_return(find_profile_response2)

    service
  end

  let(:email_address) { 'testuser@test.com' }
  let(:emails) { build(:email, email_address:) }
  let(:person) { build(:person, emails:) }
  let(:person_response) { instance_double(VAProfile::ContactInformation::PersonResponse, person:) }

  let(:email_address2) { 'testuser2@test.com' }
  let(:emails2) { build(:email, email_address: email_address2) }
  let(:person2) { build(:person, emails: emails2) }
  let(:person_response2) { instance_double(VAProfile::ContactInformation::PersonResponse, person: person2) }

  before do
    allow(VaNotify::Service).to receive(:new).and_return(vanotify_service)
    allow(MPI::Service).to receive(:new).and_return(mpi_service)

    allow(VAProfile::ContactInformation::Service).to receive(:get_person)
    allow(VAProfile::ContactInformation::Service).to receive(:get_person)
      .with(mpi_profile&.vet360_id)
      .and_return(person_response)
    allow(VAProfile::ContactInformation::Service).to receive(:get_person)
      .with(mpi_profile2.vet360_id)
      .and_return(person_response2)
  end

  describe 'perform' do
    context 'with flag enabled', :aggregate_failures do
      before do
        Flipper.enable :decision_review_failure_notification_email_job_enabled

        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      context 'SavedClaim records are present with a form error status' do
        let(:created_at) { DateTime.new(2023, 4, 2) }
        let(:personalisation) do
          {
            first_name: mpi_profile.given_names[0],
            date_submitted: created_at.strftime('%B %d, %Y'),
            filename: nil
          }
        end
        let(:reference) { "SC-form-#{guid1}" }

        before do
          SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}', metadata: '{"status":"error"}')
          SavedClaim::SupplementalClaim.create(guid: guid2, form: '{}',
                                               metadata: '{"status":"error"}')
          SavedClaim::SupplementalClaim.create(guid: guid3, form: '{}', metadata: '{"status":"pending"}')

          create(:appeal_submission, user_uuid:, type_of_appeal: 'SC', submitted_appeal_uuid: guid1, created_at:)
          create(:appeal_submission, user_uuid:, type_of_appeal: 'SC', submitted_appeal_uuid: guid2,
                                     failure_notification_sent_at: DateTime.new(2023, 1, 2))
          create(:appeal_submission, user_uuid:, type_of_appeal: 'SC', submitted_appeal_uuid: guid3)
        end

        it 'sends email for form and sets notification date if email has not been sent' do
          frozen_time = DateTime.new(2024, 1, 1).utc

          Timecop.freeze(frozen_time) do
            subject.new.perform

            submission1 = AppealSubmission.find_by(submitted_appeal_uuid: guid1)
            expect(submission1.failure_notification_sent_at).to eq frozen_time

            submission2 = AppealSubmission.find_by(submitted_appeal_uuid: guid2)
            expect(submission2.failure_notification_sent_at).to eq DateTime.new(2023, 1, 2)

            submission3 = AppealSubmission.find_by(submitted_appeal_uuid: guid3)
            expect(submission3.failure_notification_sent_at).to be_nil

            expect(mpi_service).not_to have_received(:find_profile_by_identifier)
              .with(identifier: user_uuid2, identifier_type: anything)

            expect(vanotify_service).to have_received(:send_email).with({ email_address:,
                                                                          personalisation:,
                                                                          reference:,
                                                                          template_id: 'fake_sc_template_id' })

            expect(vanotify_service).not_to have_received(:send_email).with({ email_address: anything,
                                                                              personalisation: anything,
                                                                              reference: anything,
                                                                              template_id: 'fake_nod_template_id' })

            expect(vanotify_service).not_to have_received(:send_email).with({ email_address: anything,
                                                                              personalisation: anything,
                                                                              reference: anything,
                                                                              template_id: 'fake_hlr_template_id' })

            logger_params = [
              'DecisionReview::FailureNotificationEmailJob form email queued',
              { submitted_appeal_uuid: guid1, appeal_type: 'SC', notification_id: }
            ]
            expect(Rails.logger).to have_received(:info).with(*logger_params)
            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.failure_notification_email.form.email_queued', tags: ['appeal_type:SC'])
          end
        end
      end

      context 'SavedClaim records are present with evidence error status' do
        let(:upload_guid1) { SecureRandom.uuid }
        let(:upload_guid2) { SecureRandom.uuid }
        let(:upload_guid3) { SecureRandom.uuid }
        let(:upload_guid4) { SecureRandom.uuid }
        let(:upload_guid5) { SecureRandom.uuid }

        let(:metadata1) do
          {
            'status' => 'success',
            'updatedAt' => '2023-01-02T00:00:00.000Z',
            'createdAt' => '2023-01-02T00:00:00.000Z',
            'uploads' => [
              {
                'status' => 'error',
                'detail' => 'Blank images',
                'createDate' => '2023-01-02T00:00:00.000Z',
                'updateDate' => '2023-01-02T00:00:00.000Z',
                'id' => upload_guid1
              },
              {
                'status' => 'vbms',
                'detail' => nil,
                'createDate' => '2023-01-03T00:00:00.000Z',
                'updateDate' => '2023-01-03T00:00:00.000Z',
                'id' => upload_guid2
              },
              {
                'status' => 'error',
                'detail' => 'Corrupt file',
                'createDate' => '2023-01-04T00:00:00.000Z',
                'updateDate' => '2023-01-04T00:00:00.000Z',
                'id' => upload_guid3
              }
            ]
          }
        end

        let(:metadata2) do
          {
            'status' => 'complete',
            'updatedAt' => '2023-01-02T00:00:00.000Z',
            'createdAt' => '2023-01-02T00:00:00.000Z',
            'uploads' => [
              {
                'status' => 'processing',
                'detail' => nil,
                'createDate' => '2023-01-03T00:00:00.000Z',
                'updateDate' => '2023-01-03T00:00:00.000Z',
                'id' => upload_guid4
              }
            ]
          }
        end

        let(:metadata3) do
          {
            'status' => 'success',
            'updatedAt' => '2023-01-02T00:00:00.000Z',
            'createdAt' => '2023-01-02T00:00:00.000Z',
            'uploads' => [
              {
                'status' => 'error',
                'detail' => 'Unable to associate with veteran',
                'createDate' => '2023-01-03T00:00:00.000Z',
                'updateDate' => '2023-01-03T00:00:00.000Z',
                'id' => upload_guid5
              }
            ]
          }
        end

        let(:filename1) { 'error_blank_images.pdf' }
        let(:filename2) { 'vbms_file.pdf' }
        let(:filename3) { 'error_pdf_notification_emailed_already.pdf' }
        let(:filename4) { 'success_file.pdf' }
        let(:filename5) { 'error_veteran_not_found.pdf' }
        let(:masked_filename1) { 'errXX_XXXXX_XXXXes.pdf' }
        let(:masked_filename5) { 'errXX_XXXXXXX_XXX_XXXnd.pdf' }

        let(:created_at) { DateTime.new(2023, 4, 2) }
        let(:personalisation) do
          {
            first_name: mpi_profile.given_names[0],
            filename: masked_filename1,
            date_submitted: created_at.strftime('%B %d, %Y')
          }
        end
        let(:personalisation2) do
          {
            first_name: mpi_profile2.given_names[0],
            filename: masked_filename5,
            date_submitted: created_at.strftime('%B %d, %Y')
          }
        end
        let(:reference) { "NOD-evidence-#{upload_guid1}" }
        let(:reference2) { "NOD-evidence-#{upload_guid5}" }

        before do
          SavedClaim::NoticeOfDisagreement.create(guid: guid1, form: '{}', metadata: metadata1.to_json)
          SavedClaim::NoticeOfDisagreement.create(guid: guid2, form: '{}', metadata: metadata2.to_json)
          SavedClaim::NoticeOfDisagreement.create(guid: guid3, form: '{}', metadata: metadata3.to_json)
          SavedClaim::NoticeOfDisagreement.create(guid: guid4, form: '{}', metadata: nil)

          # 1 error no email, 1 vbms, 1 error already emailed
          appeal_submission = create(:appeal_submission, user_uuid:, submitted_appeal_uuid: guid1, created_at:)
          # 1 processing
          appeal_submission2 = create(:appeal_submission, submitted_appeal_uuid: guid2, created_at:)
          # 1 error
          appeal_submission3 = create(:appeal_submission, user_uuid: user_uuid2, submitted_appeal_uuid: guid3,
                                                          created_at:)
          # no metadata
          create(:appeal_submission, submitted_appeal_uuid: guid4, created_at:)

          upload1 = create(:appeal_submission_upload, lighthouse_upload_id: upload_guid1, appeal_submission:,
                                                      created_at:)
          upload2 = create(:appeal_submission_upload, lighthouse_upload_id: upload_guid2, appeal_submission:,
                                                      created_at:)
          upload3 = create(:appeal_submission_upload, lighthouse_upload_id: upload_guid3, appeal_submission:,
                                                      failure_notification_sent_at: DateTime.new(2023, 1, 2))
          upload4 = create(:appeal_submission_upload, lighthouse_upload_id: upload_guid4,
                                                      appeal_submission: appeal_submission2)
          upload5 = create(:appeal_submission_upload, lighthouse_upload_id: upload_guid5,
                                                      appeal_submission: appeal_submission3, created_at:)

          with_settings(Settings.decision_review.pdf_validation, enabled: false) do
            create(:decision_review_evidence_attachment, guid: upload1.decision_review_evidence_attachment_guid,
                                                         file_data: { filename: filename1 }.to_json)
            create(:decision_review_evidence_attachment, guid: upload2.decision_review_evidence_attachment_guid,
                                                         file_data: { filename: filename2 }.to_json)
            create(:decision_review_evidence_attachment, guid: upload3.decision_review_evidence_attachment_guid,
                                                         file_data: { filename: filename3 }.to_json)
            create(:decision_review_evidence_attachment, guid: upload4.decision_review_evidence_attachment_guid,
                                                         file_data: { filename: filename4 }.to_json)
            create(:decision_review_evidence_attachment, guid: upload5.decision_review_evidence_attachment_guid,
                                                         file_data: { filename: filename5 }.to_json)
          end
        end

        it 'sends email for evidence file and sets upload notification date if email has not been sent' do
          frozen_time = DateTime.new(2024, 1, 1).utc

          Timecop.freeze(frozen_time) do
            subject.new.perform

            expect(vanotify_service).to have_received(:send_email).with({ email_address:,
                                                                          template_id: 'fake_nod_evidence_template_id',
                                                                          reference:,
                                                                          personalisation: })

            expect(vanotify_service).to have_received(:send_email).with({ email_address: email_address2,
                                                                          template_id: 'fake_nod_evidence_template_id',
                                                                          reference: reference2,
                                                                          personalisation: personalisation2 })

            upload1 = AppealSubmissionUpload.find_by(lighthouse_upload_id: upload_guid1)
            expect(upload1.failure_notification_sent_at).to eq frozen_time

            upload2 = AppealSubmissionUpload.find_by(lighthouse_upload_id: upload_guid2)
            expect(upload2.failure_notification_sent_at).to be_nil

            upload3 = AppealSubmissionUpload.find_by(lighthouse_upload_id: upload_guid3)
            expect(upload3.failure_notification_sent_at).to eq DateTime.new(2023, 1, 2)

            upload4 = AppealSubmissionUpload.find_by(lighthouse_upload_id: upload_guid4)
            expect(upload4.failure_notification_sent_at).to be_nil

            upload5 = AppealSubmissionUpload.find_by(lighthouse_upload_id: upload_guid5)
            expect(upload5.failure_notification_sent_at).to eq frozen_time

            expect(mpi_service).to have_received(:find_profile_by_identifier)
              .with(identifier: user_uuid, identifier_type: 'idme').once
            expect(mpi_service).to have_received(:find_profile_by_identifier)
              .with(identifier: user_uuid2, identifier_type: 'idme').once

            logger_params = [
              'DecisionReview::FailureNotificationEmailJob evidence email queued',
              { submitted_appeal_uuid: guid1, lighthouse_upload_id: upload_guid1, appeal_type: 'NOD', notification_id: }
            ]
            expect(Rails.logger).to have_received(:info).with(*logger_params)

            logger_params2 = [
              'DecisionReview::FailureNotificationEmailJob evidence email queued',
              {
                submitted_appeal_uuid: guid3,
                lighthouse_upload_id: upload_guid5,
                appeal_type: 'NOD',
                notification_id: notification_id2
              }
            ]
            expect(Rails.logger).to have_received(:info).with(*logger_params2)

            expect(StatsD).to have_received(:increment)
              .with('worker.decision_review.failure_notification_email.evidence.email_queued',
                    tags: ['appeal_type:NOD'])
              .exactly(2).times
          end
        end
      end

      context 'when an error occurs during form processing' do
        let(:email_address) { nil }
        let(:message) { 'Failed to retrieve email address' }

        before do
          SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}', metadata: '{"status":"error"}')
          create(:appeal_submission, type_of_appeal: 'SC', submitted_appeal_uuid: guid1)
        end

        it 'handles the error and increments the statsd metric' do
          expect { subject.new.perform }.not_to raise_exception

          logger_params = [
            'DecisionReview::FailureNotificationEmailJob form error',
            { submitted_appeal_uuid: guid1, appeal_type: 'SC', message: }
          ]
          expect(Rails.logger).to have_received(:error).with(*logger_params)
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.failure_notification_email.form.error', tags: ['appeal_type:SC'])
        end
      end

      context 'when an error occurs during evidence processing' do
        let(:mpi_profile) { nil }

        let(:lighthouse_upload_id) { SecureRandom.uuid }
        let(:metadata) do
          {
            'status' => 'success',
            'updatedAt' => '2023-01-02T00:00:00.000Z',
            'createdAt' => '2023-01-02T00:00:00.000Z',
            'uploads' => [
              {
                'status' => 'error',
                'detail' => 'Unable to associate with veteran',
                'createDate' => '2023-01-03T00:00:00.000Z',
                'updateDate' => '2023-01-03T00:00:00.000Z',
                'id' => lighthouse_upload_id
              }
            ]
          }
        end
        let(:filename) { 'evidence.pdf' }

        let(:message) { 'Failed to fetch MPI profile' }

        before do
          SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}', metadata: metadata.to_json)
          appeal_submission = create(:appeal_submission, type_of_appeal: 'SC', submitted_appeal_uuid: guid1)

          upload = create(:appeal_submission_upload, lighthouse_upload_id:, appeal_submission:)

          with_settings(Settings.decision_review.pdf_validation, enabled: false) do
            create(:decision_review_evidence_attachment, guid: upload.decision_review_evidence_attachment_guid,
                                                         file_data: { filename: }.to_json)
          end
        end

        it 'handles the error and increments the statsd metric' do
          expect { subject.new.perform }.not_to raise_exception

          logger_params = [
            'DecisionReview::FailureNotificationEmailJob evidence error',
            { submitted_appeal_uuid: guid1, lighthouse_upload_id:, appeal_type: 'SC', message: }
          ]
          expect(Rails.logger).to have_received(:error).with(*logger_params)
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.failure_notification_email.evidence.error', tags: ['appeal_type:SC'])
        end
      end

      context 'when there are no errors to email' do
        before do
          SavedClaim::SupplementalClaim.create(guid: guid1, form: '{}')
        end

        it 'does not send emails' do
          expect(vanotify_service).not_to receive(:send_email)

          subject.new.perform
        end
      end
    end

    context 'with flag disabled' do
      before do
        Flipper.disable :decision_review_failure_notification_email_job_enabled
      end

      it 'immediately exits' do
        expect(SavedClaim).not_to receive(:where)

        subject.new.perform
      end
    end
  end
end
