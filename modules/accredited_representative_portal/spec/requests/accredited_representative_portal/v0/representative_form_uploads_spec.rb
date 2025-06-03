# frozen_string_literal: true

require_relative '../../../rails_helper'
require 'simple_forms_api_submission/metadata_validator'
require 'common/file_helpers'

RSpec.describe AccreditedRepresentativePortal::V0::RepresentativeFormUploadController, type: :request do
  let!(:poa_code) { '067' }
  let(:representative_user) { create(:representative_user, email: 'test@va.gov', icn: '123498767V234859') }
  let(:service) { BenefitsIntake::Service.new }
  let(:pdf_path) { 'random/path/to/pdf' }
  let!(:accredited_individual) do
    create(:user_account_accredited_individual,
           user_account_email: representative_user.email,
           user_account_icn: representative_user.icn,
           accredited_individual_registration_number: '357458',
           poa_code:)
  end
  let!(:representative) do
    create(:representative,
           :vso,
           representative_id: accredited_individual.accredited_individual_registration_number,
           poa_codes: [poa_code])
  end

  let!(:vso) { create(:organization, poa: poa_code, can_accept_digital_poa_requests: true) }
  let(:form_number) { '21-686c' }
  let(:arp_vcr_path) do
    'accredited_representative_portal/requests/accredited_representative_portal/v0/representative_form_uploads_spec/'
  end

  before do
    login_as(representative_user)
  end

  describe '#submit' do
    let(:representative_fixture_path) do
      Rails.root.join('modules', 'accredited_representative_portal', 'spec', 'fixtures', 'form_data',
                      'representative_form_upload_21_686c.json')
    end
    let(:veteran_params) { JSON.parse(representative_fixture_path.read) }

    let(:claimant_fixture_path) do
      Rails.root.join('modules', 'accredited_representative_portal', 'spec', 'fixtures', 'form_data',
                      'claimant_form_upload_21_686c.json')
    end
    let(:claimant_params) { JSON.parse(claimant_fixture_path.read) }
    let(:form_name) { 'Request for Nursing Home Information in Connection with Claim for Aid and Attendance' }
    let(:metadata_file) { "#{file_seed}.SimpleFormsApi.metadata.json" }
    let(:file_seed) { 'tmp/some-unique-simple-forms-file-seed' }
    let(:random_string) { 'some-unique-simple-forms-file-seed' }
    let(:pdf_path) do
      Rails.root.join('modules', 'accredited_representative_portal', 'spec', 'fixtures', 'files',
                      '21_686c_empty_form.pdf')
    end
    let(:pdf_stamper) { double(stamp_pdf: nil) }
    let(:confirmation_code) { '123456' }
    let(:attachment) { double }

    before do
      allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('<TOKEN>')
      allow(Common::FileHelpers).to receive(:random_file_path).and_return(file_seed)
      allow(Common::FileHelpers).to receive(:generate_clamav_temp_file).and_wrap_original do |original_method, *args|
        original_method.call(args[0], random_string)
      end
      allow(SimpleFormsApi::PdfStamper).to receive(:new).with(stamped_template_path: pdf_path.to_s, current_loa: 3,
                                                              timestamp: anything).and_return(pdf_stamper)
      allow(attachment).to receive(:to_pdf).and_return(pdf_path)
      allow(PersistentAttachment).to receive(:find_by).with(guid: confirmation_code).and_return(attachment)
    end

    after do
      Common::FileHelpers.delete_file_if_exists(metadata_file)
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
        VCR.insert_cassette("#{arp_vcr_path}mpi/invalid_icn_full")
        VCR.use_cassette("#{arp_vcr_path}lighthouse/200_response") do
          post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)
          expect(response).to have_http_status(:forbidden)
        end
        VCR.eject_cassette("#{arp_vcr_path}mpi/invalid_icn_full")
      end
    end

    context 'claimant with matching poa found' do
      around do |example|
        VCR.insert_cassette("#{arp_vcr_path}mpi/valid_icn_full")
        VCR.insert_cassette('lighthouse/benefits_claims/power_of_attorney/200_response')
        VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
        VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
        example.run
        VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
        VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
        VCR.eject_cassette('lighthouse/benefits_claims/power_of_attorney/200_response')
        VCR.eject_cassette("#{arp_vcr_path}mpi/valid_icn_full")
      end

      it 'makes the veteran request' do
        expect(PersistentAttachment).to receive(:find_by).with(guid: confirmation_code).and_return(attachment)
        post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

        expect(response).to have_http_status(:ok)
      end

      it 'makes the claimant request' do
        expect(PersistentAttachment).to receive(:find_by).with(guid: confirmation_code).and_return(attachment)
        post('/accredited_representative_portal/v0/submit_representative_form', params: claimant_params)

        expect(response).to have_http_status(:ok)
      end

      it 'stamps the pdf' do
        expect(pdf_stamper).to receive(:stamp_pdf)

        post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

        expect(response).to have_http_status(:ok)
      end

      it 'saves the FormSubmission and FormSubmissionAttempt' do
        form_submission = double
        expect(FormSubmission).to receive(:create).with(
          form_type: form_number,
          form_data: veteran_params['representative_form_upload']['formData'].to_json,
          user_account: representative_user.user_account
        ).and_return(form_submission)
        expect(FormSubmissionAttempt).to receive(:create).with(
          form_submission:,
          benefits_intake_uuid: anything
        )

        post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

        expect(response).to have_http_status(:ok)
      end

      it 'checks if the prefill data has been changed' do
        prefill_data = double
        prefill_data_service = double
        in_progress_form = double(form_data: prefill_data)

        allow(SimpleFormsApi::PrefillDataService).to receive(:new).with(
          prefill_data:,
          form_data: hash_including(:email),
          form_id: form_number
        ).and_return(prefill_data_service)
        allow(InProgressForm).to receive(:form_for_user).with(form_number,
                                                              anything).and_return(in_progress_form)

        post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe '#upload_scanned_form' do
    it 'renders the attachment as json' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
      file = fixture_file_upload('doctors-note.gif')

      params = { form_id: form_number, file: }

      allow_any_instance_of(BenefitsIntake::Service).to receive(:valid_document?).and_return(pdf_path)

      expect do
        post '/accredited_representative_portal/v0/representative_form_upload', params:
      end.to change(PersistentAttachments::VAForm, :count).by(1)
      attachment = PersistentAttachment.last

      expect(response).to have_http_status(:ok)
      resp = JSON.parse(response.body)
      expect(resp).to eq({
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
    
      allow_any_instance_of(BenefitsIntake::Service).to receive(:valid_document?)
        .and_raise(BenefitsIntake::Service::InvalidDocumentError.new('Invalid form'))
    
      expect do
        post '/accredited_representative_portal/v0/representative_form_upload', params:
      end.not_to change(PersistentAttachments::VAForm, :count)
    
      expect(response).to have_http_status(:unprocessable_entity)
      resp = JSON.parse(response.body)
      expect(resp['error']).to eq('Document validation failed: Invalid form')
    end
  end

  describe '#submit_supporting_documents' do
    it 'renders the attachment as json' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
      file = fixture_file_upload('doctors-note.gif')

      params = { form_id: form_number, file: }

      allow_any_instance_of(BenefitsIntake::Service).to receive(:valid_document?).and_return(pdf_path)

      expect do
        post '/accredited_representative_portal/v0/submit_supporting_documents', params:
      end.to change(PersistentAttachments::VAFormDocumentation, :count).by(1)
      attachment = PersistentAttachment.last

      expect(response).to have_http_status(:ok)
      resp = JSON.parse(response.body)
      expect(resp).to eq({
                          'data' => {
                            'id' => attachment.id.to_s,
                            'type' => 'persistent_attachment_va_form',
                            'attributes' => {
                              'confirmationCode' => attachment.guid,
                              'name' => 'doctors-note.gif',
                              'size' => 83_403,
                              'warnings' => []
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
    
      allow_any_instance_of(BenefitsIntake::Service).to receive(:valid_document?)
        .and_raise(BenefitsIntake::Service::InvalidDocumentError.new('Invalid form'))
    
      expect do
        post '/accredited_representative_portal/v0/submit_supporting_documents', params:
      end.not_to change(PersistentAttachments::VAFormDocumentation, :count)
    
      expect(response).to have_http_status(:unprocessable_entity)
      resp = JSON.parse(response.body)
      expect(resp['error']).to eq('Document validation failed: Invalid form')
    end
  end
end
