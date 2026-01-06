# frozen_string_literal: true

require_relative '../../../rails_helper'
require 'benefits_intake_service/service'

RSpec.describe AccreditedRepresentativePortal::V0::RepresentativeFormUploadController, :uploader_helpers,
               type: :request do
  stub_virus_scan
  let!(:poa_code) { '067' }
  let(:representative_user) do
    create(
      :representative_user,
      email: 'test@va.gov',
      icn: '123498767V234859',
      all_emails: ['test@va.gov']
    )
  end
  let(:service) { BenefitsIntakeService::Service.new }
  let(:pdf_path) { 'random/path/to/pdf' }
  let!(:representative) do
    create(
      :representative,
      :vso,
      email: representative_user.email,
      representative_id: '357458',
      poa_codes: [poa_code]
    )
  end

  let!(:vso) { create(:organization, poa: poa_code) }
  let(:form_number) { '21-686c' }
  let(:arp_vcr_path) do
    'accredited_representative_portal/requests/accredited_representative_portal/v0/representative_form_uploads_spec/'
  end

  before do
    VCR.eject_cassette("#{arp_vcr_path}mpi/valid_icn_full")
    login_as(representative_user)
  end

  describe '#submit' do
    let(:attachment_guid) { '743a0ec2-6eeb-49b9-bd70-0a195b74e9f3' }
    let(:supporting_attachment_guid) { '743a0ec2-6eeb-49b9-bd70-0a195b74e9f2' }
    let!(:attachment) { PersistentAttachments::VAForm.create!(guid: attachment_guid, form_id: '21-686c') }
    let!(:supporting_attachment) do
      PersistentAttachments::VAFormDocumentation.create!(guid: supporting_attachment_guid, form_id: '21-686c')
    end
    let(:representative_fixture_path) do
      Rails.root.join(
        'modules', 'accredited_representative_portal', 'spec', 'fixtures', 'form_data',
        'representative_form_upload_21_686c.json'
      )
    end
    let(:veteran_params) do
      JSON.parse(representative_fixture_path.read).tap do |memo|
        memo['representative_form_upload']['confirmationCode'] = attachment_guid
      end
    end

    let(:multi_form_veteran_params) do
      JSON.parse(representative_fixture_path.read).tap do |memo|
        memo['representative_form_upload']['confirmationCode'] = attachment_guid
        memo['representative_form_upload']['supportingDocuments'] = [
          {
            'confirmationCode' => supporting_attachment_guid,
            'name' => 'supporting_document.pdf',
            'size' => 12_345
          }
        ]
      end
    end

    let(:invalid_form_fixture_path) do
      Rails.root.join(
        'modules', 'accredited_representative_portal', 'spec', 'fixtures', 'form_data',
        'invalid_form_number.json'
      )
    end
    let(:invalid_form_params) do
      JSON.parse(invalid_form_fixture_path.read).merge('confirmationCode' => attachment_guid)
    end

    let(:claimant_fixture_path) do
      Rails.root.join(
        'modules', 'accredited_representative_portal', 'spec', 'fixtures', 'form_data',
        'claimant_form_upload_21_686c.json'
      )
    end
    let(:claimant_params) do
      JSON.parse(claimant_fixture_path.read).tap do |memo|
        memo['representative_form_upload']['confirmationCode'] = attachment_guid
      end
    end
    let(:form_name) do
      'Request for Nursing Home Information in Connection with Claim for Aid and Attendance'
    end
    let(:pdf_path) do
      Rails.root.join(
        'modules', 'accredited_representative_portal', 'spec', 'fixtures', 'files',
        '21_686c_empty_form.pdf'
      )
    end

    before do
      allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('<TOKEN>')
    end

    context 'cannot lookup claimant' do
      it 'returns a 404 error' do
        VCR.use_cassette('mpi/find_candidate/invalid_icn') do
          post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'claimant found without matching poa' do
      it 'returns a 403 error' do
        VCR.use_cassette("#{arp_vcr_path}mpi/invalid_icn_full") do
          VCR.use_cassette("#{arp_vcr_path}lighthouse/empty_response") do
            post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end

    context 'LH benefits intake - too many requests error' do
      let(:service) { double }

      before do
        allow_any_instance_of(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:process_record).and_return 'pdf_path'
        allow_any_instance_of(BenefitsIntakeService::Service).to receive(:get_upload_docs).and_return(['{}', nil])
      end

      it 'returns a 429 error' do
        VCR.use_cassette("#{arp_vcr_path}mpi/valid_icn_full") do
          VCR.use_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response") do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
              VCR.use_cassette("#{arp_vcr_path}lighthouse/429_response") do
                post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)
                expect(response).to have_http_status(:service_unavailable)
                expect(JSON.parse(response.body)['errors'][0]['detail']).to eq 'Temporary system issue'
              end
            end
          end
        end
      end
    end

    context '21-686c form' do
      before do
        allow_any_instance_of(AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob).to(
          receive(:perform) do |_instance, saved_claim_id|
            claim = SavedClaim.find(saved_claim_id)
            claim.form_submissions << create(:form_submission, :pending)
            claim.save!
          end
        )
      end

      context 'claimant with matching claims agent POA found' do
        let!(:claims_agent) do
          create(
            :representative,
            :claim_agents,
            email: representative_user.email,
            representative_id: '468569',
            poa_codes: ['068']
          )
        end

        around do |example|
          VCR.use_cassette("#{arp_vcr_path}mpi/valid_icn_full") do
            VCR.use_cassette("#{arp_vcr_path}lighthouse/200_type_individual_response") do
              VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
                VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
                  example.run
                end
              end
            end
          end
        end

        it 'makes the veteran request' do
          post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)
          expect(response).to have_http_status(:ok)
          expect(parsed_response).to eq(
            {
              'confirmationNumber' => FormSubmissionAttempt.order(created_at: :desc).first.benefits_intake_uuid,
              'status' => '200'
            }
          )
        end
      end

      context 'claimant with matching VSO POA found' do
        around do |example|
          VCR.use_cassette("#{arp_vcr_path}mpi/valid_icn_full") do
            VCR.use_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response") do
              VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
                VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
                  example.run
                end
              end
            end
          end
        end

        context 'when email sending succeeds' do
          before do
            notification_double = double('notification')
            allow(AccreditedRepresentativePortal::NotificationEmail).to receive(:new).and_return(notification_double)
            expect(notification_double).to receive(:deliver).with(:confirmation)
          end

          it 'makes the veteran request' do
            post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)
            expect(response).to have_http_status(:ok)
            expect(parsed_response).to eq(
              {
                'confirmationNumber' => FormSubmissionAttempt.order(created_at: :desc).first.benefits_intake_uuid,
                'status' => '200'
              }
            )
          end

          it 'makes the veteran request with multiple attachments' do
            post('/accredited_representative_portal/v0/submit_representative_form', params: multi_form_veteran_params)
            expect(response).to have_http_status(:ok)
            expect(parsed_response).to eq(
              {
                'confirmationNumber' => FormSubmissionAttempt.order(created_at: :desc).first.benefits_intake_uuid,
                'status' => '200'
              }
            )
          end

          it 'makes the claimant request' do
            post('/accredited_representative_portal/v0/submit_representative_form', params: claimant_params)
            expect(response).to have_http_status(:ok)
            expect(parsed_response).to eq(
              {
                'confirmationNumber' => FormSubmissionAttempt.order(created_at: :desc).first.benefits_intake_uuid,
                'status' => '200'
              }
            )
          end
        end

        it 'applies form_id and org tags on span and root trace during submit' do
          span_double  = double('Span')
          trace_double = double('Trace')

          allow(span_double).to receive(:set_tag)
          allow(trace_double).to receive(:set_tag)

          real_monitor = AccreditedRepresentativePortal::Monitoring.new(
            AccreditedRepresentativePortal::Monitoring::NAME,
            default_tags: []
          )

          allow(AccreditedRepresentativePortal::Monitoring)
            .to receive(:new)
            .and_return(real_monitor)

          allow(real_monitor).to receive(:trace) { |*_args, &blk| blk.call(span_double) }
          allow(Datadog::Tracing).to receive(:active_trace).and_return(trace_double)

          post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)
          expect(response).to have_http_status(:ok)

          expect(span_double).to have_received(:set_tag).with(satisfy { |k| k.to_s == 'form_id' }, form_number)
          expect(span_double).to have_received(:set_tag).with(satisfy { |k| k.to_s == 'org' }, '067')

          expect(trace_double).to have_received(:set_tag).with(satisfy { |k| k.to_s == 'form_id' }, form_number)
          expect(trace_double).to have_received(:set_tag).with(satisfy { |k| k.to_s == 'org' }, '067')
        end

        context 'when email sending fails' do
          it 'still returns success but logs the error' do
            allow(AccreditedRepresentativePortal::NotificationEmail)
              .to receive(:new).and_raise(StandardError.new('Email failed'))
            expect_any_instance_of(AccreditedRepresentativePortal::Monitor).to receive(:track_send_email_failure)

            post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)
            expect(response).to have_http_status(:ok)
          end
        end
      end
    end

    context '21-526EZ form' do
      let(:form_number) { '21-526EZ' }
      let(:representative_fixture_path) do
        Rails.root.join(
          'modules', 'accredited_representative_portal', 'spec', 'fixtures', 'form_data',
          'representative_form_upload_21_526EZ.json'
        )
      end
      let(:pdf_path) do
        Rails.root.join(
          'modules', 'accredited_representative_portal', 'spec', 'fixtures', 'files',
          'VBA-21-526EZ-ARE.pdf'
        )
      end
      let!(:attachment) { PersistentAttachments::VAForm.create!(guid: attachment_guid, form_id: '21-526EZ') }
      let!(:supporting_attachment) do
        PersistentAttachments::VAFormDocumentation.create!(guid: supporting_attachment_guid, form_id: '21-526EZ')
      end

      before do
        allow_any_instance_of(AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob).to(
          receive(:perform) do |_instance, saved_claim_id|
            claim = SavedClaim.find(saved_claim_id)
            claim.form_submissions << create(:form_submission, :pending)
            claim.save!
          end
        )
      end

      around do |example|
        VCR.use_cassette("#{arp_vcr_path}mpi/valid_icn_full") do
          VCR.use_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response") do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
              VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
                example.run
              end
            end
          end
        end
      end

      context 'claimant with matching poa found' do
        it 'makes the veteran request' do
          post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)
          expect(response).to have_http_status(:ok)
          expect(parsed_response).to eq(
            {
              'confirmationNumber' => FormSubmissionAttempt.order(created_at: :desc).first.benefits_intake_uuid,
              'status' => '200'
            }
          )
        end

        it 'makes the veteran request with multiple attachments' do
          post('/accredited_representative_portal/v0/submit_representative_form', params: multi_form_veteran_params)
          expect(response).to have_http_status(:ok)
          expect(parsed_response).to eq(
            {
              'confirmationNumber' => FormSubmissionAttempt.order(created_at: :desc).first.benefits_intake_uuid,
              'status' => '200'
            }
          )
        end
      end
    end

    describe 'track_count is called for a submission attempt' do
      let(:monitor_instance) do
        AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags: []
        )
      end

      before do
        allow_any_instance_of(described_class).to receive(:verify_authorized).and_return(true)
        allow(AccreditedRepresentativePortal::Monitoring).to receive(:new).and_return(monitor_instance)
        allow(monitor_instance).to receive(:track_count)
        allow_any_instance_of(AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob).to(
          receive(:perform) do |_instance, saved_claim_id|
            claim = SavedClaim.find(saved_claim_id)
            claim.form_submissions << create(:form_submission, :pending)
            claim.save!
          end
        )
      end

      it 'increments ar.claims.form_upload.submit.attempt once per request' do
        VCR.use_cassette("#{arp_vcr_path}mpi/valid_icn_full") do
          VCR.use_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response") do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
              VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
                post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

                expect(response).to have_http_status(:ok)
                expect(monitor_instance).to have_received(:track_count).with(
                  'ar.claims.form_upload.submit.attempt',
                  tags: array_including("form_id:#{form_number}")
                ).once
              end
            end
          end
        end
      end
    end

    describe 'track_count is called for a submission success' do
      let(:monitor_instance) do
        AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags: []
        )
      end

      before do
        allow_any_instance_of(described_class).to receive(:verify_authorized).and_return(true)
        allow(AccreditedRepresentativePortal::Monitoring).to receive(:new).and_return(monitor_instance)
        allow(monitor_instance).to receive(:track_count)
        allow_any_instance_of(AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob).to(
          receive(:perform) do |_instance, saved_claim_id|
            claim = SavedClaim.find(saved_claim_id)
            claim.form_submissions << create(:form_submission, :pending)
            claim.save!
          end
        )
      end

      it 'increments ar.claims.form_upload.submit.success once per submission success' do
        VCR.use_cassette("#{arp_vcr_path}mpi/valid_icn_full") do
          VCR.use_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response") do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
              VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
                post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

                expect(response).to have_http_status(:ok)
                expect(monitor_instance).to have_received(:track_count).with(
                  'ar.claims.form_upload.submit.success',
                  tags: array_including("form_id:#{form_number}")
                ).once
              end
            end
          end
        end
      end
    end

    describe 'track_count is called for a submission error (RecordInvalidError)' do
      let(:monitor_instance) do
        AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags: []
        )
      end

      before do
        allow(AccreditedRepresentativePortal::Monitoring).to receive(:new).and_return(monitor_instance)
        allow(monitor_instance).to receive(:track_count)

        record = double('invalid_record', errors: double(full_messages: ['some error']))
        allow(AccreditedRepresentativePortal::SavedClaimService::Create)
          .to receive(:perform)
          .and_raise(AccreditedRepresentativePortal::SavedClaimService::Create::RecordInvalidError.new(record))
      end

      it 'increments ar.claims.form_upload.submit.error once per RecordInvalidError error' do
        VCR.use_cassette("#{arp_vcr_path}mpi/valid_icn_full") do
          VCR.use_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response") do
            post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

            expect(monitor_instance).to have_received(:track_count).with(
              'ar.claims.form_upload.submit.error',
              tags: array_including("form_id:#{form_number}", 'reason:record_invalid')
            )
          end
        end
      end
    end

    describe 'track_count is called for a submission error (WrongAttachmentsError)' do
      let(:monitor_instance) do
        AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags: []
        )
      end

      before do
        allow(AccreditedRepresentativePortal::Monitoring).to receive(:new).and_return(monitor_instance)
        allow(monitor_instance).to receive(:track_count)

        record = double('wrong_attachment', errors: double(full_messages: ['some error']))
        allow(AccreditedRepresentativePortal::SavedClaimService::Create)
          .to receive(:perform)
          .and_raise(AccreditedRepresentativePortal::SavedClaimService::Create::WrongAttachmentsError.new(record))
      end

      it 'increments ar.claims.form_upload.submit.error once per WrongAttachmentsError error' do
        VCR.use_cassette("#{arp_vcr_path}mpi/valid_icn_full") do
          VCR.use_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response") do
            post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

            expect(monitor_instance).to have_received(:track_count).with(
              'ar.claims.form_upload.submit.error',
              tags: array_including("form_id:#{form_number}", 'reason:wrong_attachments')
            )
          end
        end
      end
    end

    describe 'track_count is called for a submission error (TooManyRequestsError)' do
      let(:monitor_instance) do
        AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags: []
        )
      end

      before do
        allow(AccreditedRepresentativePortal::Monitoring).to receive(:new).and_return(monitor_instance)
        allow(monitor_instance).to receive(:track_count)

        record = double('too_many_requests', errors: double(full_messages: ['some error']))
        allow(AccreditedRepresentativePortal::SavedClaimService::Create)
          .to receive(:perform)
          .and_raise(AccreditedRepresentativePortal::SavedClaimService::Create::TooManyRequestsError.new(record))
      end

      it 'increments ar.claims.form_upload.submit.error once per TooManyRequestsError error' do
        VCR.use_cassette("#{arp_vcr_path}mpi/valid_icn_full") do
          VCR.use_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response") do
            post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

            expect(monitor_instance).to have_received(:track_count).with(
              'ar.claims.form_upload.submit.error',
              tags: array_including("form_id:#{form_number}", 'reason:too_many_requests')
            )
          end
        end
      end
    end

    describe 'track_count is called for a submission error (UnknownError)' do
      let(:monitor_instance) do
        AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags: []
        )
      end

      before do
        allow(AccreditedRepresentativePortal::Monitoring).to receive(:new).and_return(monitor_instance)
        allow(monitor_instance).to receive(:track_count)

        record = double('unknown_error', errors: double(full_messages: ['some error']))
        allow(AccreditedRepresentativePortal::SavedClaimService::Create)
          .to receive(:perform)
          .and_raise(AccreditedRepresentativePortal::SavedClaimService::Create::UnknownError.new(record))
      end

      it 'increments ar.claims.form_upload.submit.error once per UnknownError error' do
        VCR.use_cassette("#{arp_vcr_path}mpi/valid_icn_full") do
          VCR.use_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response") do
            post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

            expect(monitor_instance).to have_received(:track_count).with(
              'ar.claims.form_upload.submit.error',
              tags: array_including("form_id:#{form_number}", 'reason:unknown_error')
            )
          end
        end
      end
    end

    describe 'submit adds org_resolve:failed when organization resolution fails' do
      before do
        allow_any_instance_of(described_class).to receive(:verify_authorized).and_return(true)

        # Force org resolution to fail so org_resolve:failed is added
        allow_any_instance_of(described_class).to receive(:organization).and_return(nil)
        # Spy on Monitoring.new, allow real behavior
        allow(AccreditedRepresentativePortal::Monitoring).to receive(:new).and_call_original

        allow_any_instance_of(AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob).to(
          receive(:perform) do |_instance, saved_claim_id|
            claim = SavedClaim.find(saved_claim_id)
            claim.form_submissions << create(:form_submission, :pending)
            claim.save!
          end
        )
      end

      it 'includes org_resolve:failed in Monitoring.new default_tags' do
        VCR.use_cassette("#{arp_vcr_path}mpi/valid_icn_full") do
          VCR.use_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response") do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
              VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
                post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

                expect(response).to have_http_status(:ok)

                # Assert AccreditedRepresentativePortal::Monitoring constructor saw org_resolve:failed in default_tags
                expect(AccreditedRepresentativePortal::Monitoring).to have_received(:new).with(
                  AccreditedRepresentativePortal::Monitoring::NAME,
                  hash_including(default_tags: array_including('org_resolve:failed'))
                ).exactly(2).times
              end
            end
          end
        end
      end
    end
  end

  describe '#upload_scanned_form' do
    it 'renders the attachment as json' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
      file = fixture_file_upload('doctors-note.gif')

      params = { form_id: form_number, file: }
      allow_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?).and_return(pdf_path)

      expect do
        post '/accredited_representative_portal/v0/representative_form_upload', params:
      end.to change(PersistentAttachments::VAForm, :count).by(1)
      attachment = PersistentAttachment.last

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq({
                                      'data' => {
                                        'id' => attachment.id.to_s,
                                        'type' => 'persistent_attachment_va_form',
                                        'attributes' => {
                                          'confirmationCode' => attachment.guid,
                                          'name' => 'doctors-note.gif',
                                          'size' => 83_403,
                                          'warnings' => ['wrong_form']
                                        }
                                      }
                                    })
      expect(PersistentAttachment.last).to be_a(PersistentAttachments::VAForm)
    end

    it 'returns an error if the document is invalid' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
      file = fixture_file_upload('doctors-note.gif')

      params = { form_id: form_number, file: }

      allow_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?)
        .and_raise(BenefitsIntakeService::Service::InvalidDocumentError.new('Invalid form'))

      expect do
        post '/accredited_representative_portal/v0/representative_form_upload', params:
      end.not_to change(PersistentAttachments::VAForm, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(parsed_response).to eq({
                                      'errors' => [{
                                        'title' => 'Unprocessable Entity',
                                        'detail' => 'Invalid form',
                                        'code' => '422',
                                        'status' => '422'
                                      }]
                                    })
    end

    it 'applies form_id and org tags on span and root trace during supporting documents upload' do
      # Make uploads pass
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
      allow_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?).and_return(pdf_path)
      file = fixture_file_upload('doctors-note.gif')

      allow_any_instance_of(
        AccreditedRepresentativePortal::V0::RepresentativeFormUploadController
      ).to receive(:organization).and_return('Org Name')

      span_double  = double('Span')
      trace_double = double('Trace')
      allow(span_double).to receive(:set_tag)
      allow(trace_double).to receive(:set_tag)

      real_monitor = AccreditedRepresentativePortal::Monitoring.new(
        AccreditedRepresentativePortal::Monitoring::NAME,
        default_tags: []
      )
      allow(AccreditedRepresentativePortal::Monitoring).to receive(:new).and_return(real_monitor)
      allow(real_monitor).to receive(:trace) { |*_args, &blk| blk.call(span_double) }
      allow(real_monitor).to receive(:track_count) if real_monitor.respond_to?(:track_count)

      allow(Datadog::Tracing).to receive(:active_trace).and_return(trace_double)

      expect do
        post '/accredited_representative_portal/v0/upload_supporting_documents',
             params: { form_id: form_number, file: }
      end.to change(PersistentAttachments::VAFormDocumentation, :count).by(1)
      expect(response).to have_http_status(:ok)

      expect(span_double).to have_received(:set_tag).with(satisfy { |k| k.to_s == 'form_id' }, form_number)

      expect(trace_double).to have_received(:set_tag).with(satisfy { |k| k.to_s == 'form_id' }, form_number)

      expect(span_double).to have_received(:set_tag).with(satisfy { |k| k.to_s == 'form_upload.form_id' }, form_number)
      expect(span_double).to have_received(:set_tag).with(
        satisfy { |k| k.to_s == 'form_upload.attachment_type' },
        'PersistentAttachments::VAFormDocumentation'
      )
    end
  end

  describe '#upload_supporting_documents' do
    it 'renders the attachment as json' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
      file = fixture_file_upload('doctors-note.gif')

      params = { form_id: form_number, file: }

      allow_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?).and_return(pdf_path)

      expect do
        post '/accredited_representative_portal/v0/upload_supporting_documents', params:
      end.to change(PersistentAttachments::VAFormDocumentation, :count).by(1)
      attachment = PersistentAttachment.last

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq({
                                      'data' => {
                                        'id' => attachment.id.to_s,
                                        'type' => 'persistent_attachment',
                                        'attributes' => {
                                          'confirmationCode' => attachment.guid,
                                          'name' => 'doctors-note.gif',
                                          'size' => 83_403
                                        }
                                      }
                                    })
      expect(PersistentAttachment.last).to be_a(PersistentAttachments::VAFormDocumentation)
    end

    it 'returns an error if the document is invalid' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
      file = fixture_file_upload('doctors-note.gif')

      params = { form_id: form_number, file: }

      allow_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?)
        .and_raise(BenefitsIntakeService::Service::InvalidDocumentError.new('Invalid form'))

      expect do
        post '/accredited_representative_portal/v0/upload_supporting_documents', params:
      end.not_to change(PersistentAttachments::VAFormDocumentation, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(parsed_response).to eq({
                                      'errors' => [{
                                        'title' => 'Unprocessable Entity',
                                        'detail' => 'Invalid form',
                                        'code' => '422',
                                        'status' => '422'
                                      }]
                                    })
    end

    context 'when form_id includes -UPLOAD suffix' do
      it 'strips the suffix and processes upload' do
        clamscan = double(safe?: true)
        allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
        file = fixture_file_upload('doctors-note.gif')

        params = { form_id: "#{form_number}-UPLOAD", file: }
        allow_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?).and_return(pdf_path)

        expect do
          post '/accredited_representative_portal/v0/upload_supporting_documents', params:
        end.to change(PersistentAttachments::VAFormDocumentation, :count).by(1)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'handle_attachment_upload error handling' do
    before do
      stub_const('AccreditedRepresentativePortal::SavedClaimService', Module.new)
      stub_const('AccreditedRepresentativePortal::SavedClaimService::Attach', Module.new)

      stub_const(
        'AccreditedRepresentativePortal::SavedClaimService::Attach::RecordInvalidError',
        Class.new(StandardError) do
          attr_reader :record

          def initialize(record)
            super()
            @record = record
          end
        end
      )

      stub_const(
        'AccreditedRepresentativePortal::SavedClaimService::Attach::UpstreamInvalidError',
        Class.new(StandardError)
      )

      stub_const(
        'AccreditedRepresentativePortal::SavedClaimService::Attach::UnknownError',
        Class.new(StandardError) do
          attr_reader :cause

          def initialize(cause)
            super()
            @cause = cause
          end
        end
      )

      AccreditedRepresentativePortal::SavedClaimService::Attach.define_singleton_method(:perform) do |_klass, **_kwargs|
        nil
      end

      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
      allow_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?).and_return(pdf_path)
    end

    it 'maps UpstreamInvalidError to UpstreamUnprocessableEntity' do
      expect(AccreditedRepresentativePortal::SavedClaimService::Attach)
        .to receive(:perform)
        .and_raise(
          AccreditedRepresentativePortal::SavedClaimService::Attach::UpstreamInvalidError.new('bad upstream')
        )

      post '/accredited_representative_portal/v0/representative_form_upload',
           params: { form_id: form_number, file: fixture_file_upload('doctors-note.gif') }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'maps UnknownError to InternalServerError' do
      expect(AccreditedRepresentativePortal::SavedClaimService::Attach)
        .to receive(:perform)
        .and_raise(
          AccreditedRepresentativePortal::SavedClaimService::Attach::UnknownError.new(StandardError.new('oops'))
        )

      post '/accredited_representative_portal/v0/representative_form_upload',
           params: { form_id: form_number, file: fixture_file_upload('doctors-note.gif') }

      expect(response).to have_http_status(:internal_server_error)
    end
  end
end
