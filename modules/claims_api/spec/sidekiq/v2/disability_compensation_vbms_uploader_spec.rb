# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'
require 'claims_api/v2/disability_compensation_vbms_uploader'

RSpec.describe ClaimsApi::V2::DisabilityCompensationVBMSUploader, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    stub_claims_api_auth_token
  end

  let(:user) { FactoryBot.create(:user, :loa3) }

  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  let(:claim_date) { (Time.zone.today - 1.day).to_s }
  let(:anticipated_separation_date) { 2.days.from_now.strftime('%m-%d-%Y') }

  let(:form_data) do
    temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                           'form_526_json_api.json').read
    temp = JSON.parse(temp)
    attributes = temp['data']['attributes']
    attributes['claimDate'] = claim_date
    attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date

    temp['data']['attributes']
  end

  let(:claim) do
    claim = create(:auto_established_claim, form_data:)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  let(:supporting_document) do
    claim = create(:auto_established_claim_with_supporting_documents, :status_established)
    supporting_document = claim.supporting_documents[0]
    supporting_document.set_file_data!(
      Rack::Test::UploadedFile.new(
        Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
      ),
      'docType',
      'description'
    )
    supporting_document.save!
    supporting_document
  end

  let(:supporting_document_failed_submission) do
    supporting_document = create(:supporting_document)
    supporting_document.set_file_data!(
      Rack::Test::UploadedFile.new(
        Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
      ),
      'docType',
      'description'
    )
    supporting_document.save!
    supporting_document
  end

  describe 'successful submission' do
    let(:file_number) { '123456' }

    it 'successful submit should add the job' do
      expect do
        subject.perform_async(claim.id, file_number)
      end.to change(subject.jobs, :size).by(1)
    end

    # it 'submits successfully' do
    #   expect_any_instance_of(ClaimsApi::BD).to receive(:upload).and_return true

    #   subject.new.perform(claim.id)
    #   supporting_document.reload
    #   expect(claim.uploader.blank?).to eq(false)
    # end
  end

  # it 'if an evss_id is nil, it reschedules the sidekiq job to the future' do
  #   bd_service_stub = instance_double('ClaimsApi::BD')
  #   allow(ClaimsApi::BD).to receive(:new) { bd_service_stub }
  #   allow(bd_service_stub).to receive(:upload) { OpenStruct.new(response: 200) }

  #   subject.new.perform(supporting_document_failed_submission.id)
  #   supporting_document_failed_submission.reload
  #   expect(supporting_document.uploader.blank?).to eq(false)
  # end
end
