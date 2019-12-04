# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require_relative '../support/fake_vbms'

Sidekiq::Testing.fake!

RSpec.describe ClaimsApi::VbmsUploader, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
    @vbms_client = FakeVbms.new
    allow(VBMS::Client).to receive(:from_env_vars).and_return(@vbms_client)
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    headers = EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    headers['va_eauth_pnid'] = '796104437'
    headers
  end

  describe 'uploading a file to vbms' do
    let(:power_of_attorney) { create(:power_of_attorney) }

    it 'responds properly when there is a 500 error' do
      VCR.use_cassette('vbms/document_upload_500') do
        subject.new.perform(power_of_attorney.id)
        power_of_attorney.reload
        expect(power_of_attorney.vbms_upload_failure_count).to eq(1)
      end
    end

    it 'creates a second job if there is a failure' do
      VCR.use_cassette('vbms/document_upload_500') do
        expect do
          subject.new.perform(power_of_attorney.id)
        end.to change(subject.jobs, :size).by(1)
      end
    end

    it 'does not create an new job if had 5 failures' do
      VCR.use_cassette('vbms/document_upload_500') do
        power_of_attorney.update(vbms_upload_failure_count: 4)
        expect do
          subject.new.perform(power_of_attorney.id)
        end.to change(subject.jobs, :size).by(0)
      end
    end

    it 'updates the power of attorney record when successful response' do
      token_response = OpenStruct.new(upload_token: '<{573F054F-E9F7-4BF2-8C66-D43ADA5C62E7}')
      document_response = OpenStruct.new(
                                         upload_document_response: {
                                           '@new_document_version_ref_id' => '{52300B69-1D6E-43B2-8BEB-67A7C55346A2}',
                                           '@document_series_ref_id' => '{A57EF6CC-2236-467A-BA4F-1FA1EFD4B374}'
                                         }.with_indifferent_access
                                        )

      allow_any_instance_of(ClaimsApi::VbmsUploader).to receive(:fetch_upload_token).and_return(token_response)
      allow_any_instance_of(ClaimsApi::VbmsUploader).to receive(:upload_document).and_return(document_response)
      #<OpenStruct upload_document_response={:veteran_reference=>{:id=>{:@file_number=>"796378881"}, :@xmlns=>""}, :type_category=>{:@xmlns=>"", :@category_id=>"42", :@category_description_text=>"Representation", :@sub_category_text=>"National Service Organization ", :@type_id=>"295", :@type_description_text=>"VA 21-22 Appointment of Veterans Serv. Org. as Claimant Rep", :@type_label_text=>"L190"}, :va_receive_date=>Tue, 03 Dec 2019, :vbms_upload_date=>Tue, 03 Dec 2019, :@xmlns=>"http://service.efolder.vbms.vba.va.gov/eFolderUploadService", :"@xmlns:efu"=>"http://service.efolder.vbms.vba.va.gov/eFolderUploadService", :"@xmlns:com"=>"http://vbms.vba.va.gov/cdm/common/v4", :"@xmlns:doc"=>"http://vbms.vba.va.gov/cdm/document/v5", :"@xmlns:part"=>"http://vbms.vba.va.gov/cdm/participant/v4", :"@xmlns:efc"=>"http://service.efolder.vbms.vba.va.gov/common", :@new_document_version_ref_id=>"{FABA2ED6-EA46-4678-A6A6-07A21C17555F}", :@document_series_ref_id=>"{229A25C5-9790-4D08-B4FF-BC910BD31B0B}", :@mime_type=>"application/pdf"}>
      # allow(@vbms).to receive(:send_request).and_return(success_response)
      VCR.use_cassette('vbms/document_upload_success') do
        subject.new.perform(power_of_attorney.id)
        power_of_attorney.reload
        expect(power_of_attorney.status).to eq('uploaded')
        expect(power_of_attorney.vbms_document_series_ref_id).to eq('{A57EF6CC-2236-467A-BA4F-1FA1EFD4B374}')
        expect(power_of_attorney.vbms_new_document_version_ref_id).to eq('{52300B69-1D6E-43B2-8BEB-67A7C55346A2}')
      end
    end
  end

  private

  def create_poa
    poa = create(:power_of_attorney)
    poa.auth_headers = auth_headers
    poa.save
    poa
  end
end
