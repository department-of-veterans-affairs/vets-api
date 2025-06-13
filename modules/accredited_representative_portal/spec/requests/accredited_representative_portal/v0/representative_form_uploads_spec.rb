# frozen_string_literal: true

require_relative '../../../rails_helper'
require 'benefits_intake_service/service'

RSpec.describe AccreditedRepresentativePortal::V0::RepresentativeFormUploadController, type: :request do
  let!(:poa_code) { '067' }
  let(:representative_user) do
    create(:representative_user, email: 'test@va.gov', icn: '123498767V234859', all_emails: ['test@va.gov'])
  end
  let(:service) { BenefitsIntakeService::Service.new }
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
           email: representative_user.email,
           representative_id: accredited_individual.accredited_individual_registration_number,
           poa_codes: [poa_code])
  end

  let!(:vso) { create(:organization, poa: poa_code) }
  let(:form_number) { '21-686c' }
  let(:arp_vcr_path) do
    'accredited_representative_portal/requests/accredited_representative_portal/v0/representative_form_uploads_spec/'
  end

  before do
    login_as(representative_user)
  end

  describe '#submit' do
    let(:attachment_guid) { '743a0ec2-6eeb-49b9-bd70-0a195b74e9f3' }
    let!(:attachment) { PersistentAttachments::VAForm.create!(guid: attachment_guid) }
    let(:representative_fixture_path) do
      Rails.root.join('modules', 'accredited_representative_portal', 'spec', 'fixtures', 'form_data',
                      'representative_form_upload_21_686c.json')
    end
    let(:veteran_params) do
      JSON.parse(representative_fixture_path.read).tap do |memo|
        memo['representative_form_upload']['confirmationCode'] = attachment_guid
      end
    end
    let(:invalid_form_fixture_path) do
      Rails.root.join('modules', 'accredited_representative_portal', 'spec', 'fixtures', 'form_data',
                      'invalid_form_number.json')
    end
    let(:invalid_form_params) do
      JSON.parse(invalid_form_fixture_path.read).merge('confirmationCode' => attachment_guid)
    end

    let(:claimant_fixture_path) do
      Rails.root.join('modules', 'accredited_representative_portal', 'spec', 'fixtures', 'form_data',
                      'claimant_form_upload_21_686c.json')
    end
    let(:claimant_params) do
      JSON.parse(claimant_fixture_path.read).tap do |memo|
        memo['representative_form_upload']['confirmationCode'] = attachment_guid
      end
    end
    let(:form_name) { 'Request for Nursing Home Information in Connection with Claim for Aid and Attendance' }
    let(:pdf_path) do
      Rails.root.join('modules', 'accredited_representative_portal', 'spec', 'fixtures', 'files',
                      '21_686c_empty_form.pdf')
    end
    let!(:representative_user_account) do
      AccreditedRepresentativePortal::RepresentativeUserAccount.create!(icn: representative_user.icn)
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
        VCR.insert_cassette("#{arp_vcr_path}mpi/invalid_icn_full")
        VCR.use_cassette("#{arp_vcr_path}lighthouse/empty_response") do
          post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)
          expect(response).to have_http_status(:forbidden)
        end
        VCR.eject_cassette("#{arp_vcr_path}mpi/invalid_icn_full")
      end
    end

    context 'claimant with matching poa found' do
      around do |example|
        VCR.insert_cassette("#{arp_vcr_path}mpi/valid_icn_full")
        VCR.insert_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response")
        VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
        VCR.insert_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
        example.run
        VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload')
        VCR.eject_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location')
        VCR.eject_cassette("#{arp_vcr_path}lighthouse/200_type_organization_response")
        VCR.eject_cassette("#{arp_vcr_path}mpi/valid_icn_full")
      end

      it 'makes the veteran request' do
        post('/accredited_representative_portal/v0/submit_representative_form', params: veteran_params)
        expect(response).to have_http_status(:ok)
      end

      it 'makes the claimant request' do
        post('/accredited_representative_portal/v0/submit_representative_form', params: claimant_params)
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
                                          'warnings' => []
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
      expect(parsed_response).to eq({ 'errors' => [{ 'title' => 'Unprocessable Entity', 'detail' => 'Invalid form',
                                                     'code' => '422', 'status' => '422' }] })
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
      expect(parsed_response).to eq({ 'errors' => [{ 'title' => 'Unprocessable Entity', 'detail' => 'Invalid form',
                                                     'code' => '422', 'status' => '422' }] })
    end
  end
end
