# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/configuration'

RSpec.describe BenefitsDocuments::Configuration do
  before do
    token = 'eyJraWQiOiJoX0tZZlY0SXJSWUVvT3haVzgyNnU2ZTM1VTlSaVRyeUItRFdVNGZoZmtJIiwiYWxnIjoiUlMyNTYifQ.eyJ2ZXIiOjEsImp0aSI6IkFULkdLSjJsY3FsS2dESHdkeWFsYVBhbXdxUC1kdlEtTEp6ZE80T29zTVZOVjgiLCJpc3MiOiJodHRwczovL2RlcHR2YS1ldmFsLm9rdGEuY29tL29hdXRoMi9hdXNpM3VpODNmTGE2OElKdjJwNyIsImF1ZCI6Imh0dHBzOi8vc2FuZGJveC1hcGkudmEuZ292L3NlcnZpY2VzL2JlbmVmaXRzLWRvY3VtZW50cyIsImlhdCI6MTY5NjAxNDM3MCwiZXhwIjoxNjk2MDE0OTcwLCJjaWQiOiIwb2FqN3E5azBzR0lya1haQzJwNyIsInNjcCI6WyJkb2N1bWVudHMud3JpdGUiLCJkb2N1bWVudHMucmVhZCJdLCJzdWIiOiIwb2FqN3E5azBzR0lya1haQzJwNyIsImxhYmVsIjoiVkEuZ292IFNoYXJlZCBDbGllbnQifQ.DqrX4ejUmkAEbdiEQfWZGH0US4etuEwnwobSXjxCd06mCig2udnr-K-0m0s_iHKymiA9uUI_EZHpByb_L2bW_qsMm1rxUapM2JGuKYuR2hAe9sCR-pZ1I1t9WmjgbIx_aN-0Rnw-YnCpAMrR2kzv9Qr_CmXr7KfUYWqQ7-GMt_N_wU_gQ8OUtmn5QLgdmT3imHMtD7AmVoZL-cmiBjlMAhv-Iauv4UFPqvUXGZZI9dJL6pZlfbUI_Qf1lebrRbYsKul7RaT0MqnW4ylqConCvKS7QkdY1DzTV32lsB_VwxWrdOZPNmiollDRi3-HTesxLaLZuTkBOubTMow_vzMvew'
    allow_any_instance_of(BenefitsDocuments::Configuration).to receive(:access_token).and_return(token)
  end

  describe 'BenefitsDocuments Configuration' do
    context 'when file is pdf' do
      let(:document_data) do
        { file_number: '796378881',
          claim_id: '600423040',
          tracked_item_id: nil,
          document_type: 'L023',
          file_name: 'doctors-note.pdf' }
      end
      let(:file_body) { File.read(fixture_file_upload('doctors-note.pdf', 'application/pdf')) }

      it 'uploads expected document' do
        VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_document_upload_200') do
          response = BenefitsDocuments::Configuration.instance.post(file_body, document_data)
          expect(response.status).to eq(200)
          expect(response.body).to eq({ 'data' => { 'success' => true, 'requestId' => 74 } })
        end
      end
    end

    context 'when file is jpg' do
      let(:document_data) do
        { file_number: '796378881',
          claim_id: '600423040',
          tracked_item_id: nil,
          document_type: 'L023',
          file_name: 'doctors-note.jpg' }
      end
      let(:file_body) { File.read(fixture_file_upload('doctors-note.jpg', 'image/jpeg')) }

      it 'uploads expected document' do
        VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_document_upload_200_2',:record => :new_episodes) do
          response = BenefitsDocuments::Configuration.instance.post(file_body, document_data)
          binding.pry

          expect(response.status).to eq(200)
          expect(response.body).to eq({ 'data' => { 'success' => true, 'requestId' => 74 } })
        end
      end
    end

    context 'when file is crt' do
      let(:document_data) do
        { file_number: '796378881',
          claim_id: '600423040',
          tracked_item_id: nil,
          document_type: 'L023',
          file_name: 'idme_cert.crt' }
      end
      let(:file_body) { File.read(fixture_file_upload('idme_cert.crt')) }

      it 'raises bad request error' do
        BenefitsDocuments::Configuration.instance.post(file_body, document_data)
      rescue => e
        expect(e.errors).to eq('Invalid claim document upload file type: x-x509-ca-cert')
      end
    end
  end
end
