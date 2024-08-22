# frozen_string_literal: true

require 'rails_helper'
require 'bd/bd'

class FakeController
  include ClaimsApi::V2::ClaimsRequests::SupportingDocuments

  def local_bgs_service
    @local_bgs_service ||= ClaimsApi::LocalBGS.new(
      external_uid: target_veteran.participant_id,
      external_key: target_veteran.participant_id
    )
  end

  def target_veteran
    OpenStruct.new(
      icn: '1013062086V794840',
      first_name: 'abraham',
      last_name: 'lincoln',
      loa: { current: 3, highest: 3 },
      ssn: '796111863',
      edipi: '8040545646',
      participant_id: '600061742',
      mpi: OpenStruct.new(
        icn: '1013062086V794840',
        profile: OpenStruct.new(ssn: '796111863')
      )
    )
  end

  def benefits_doc_api
    @benefits_doc_api ||= ClaimsApi::BD.new
  end

  def claims_v2_logging(*)
    true
  end

  def params
    { id: '8675309' }
  end
end

describe ClaimsApi::V2::ClaimsRequests::SupportingDocuments do
  let(:bgs_claim) { 'Just a simple BGS Claim' }

  let(:supporting_doc_list) do
    { data: {
      documents: [
        {
          documentId: '{2161bfaa-cb21-43a6-90fc-c800c88f1234}',
          originalFileName: 'Jesse_Gray_600527334_526EZ.pdf',
          documentTypeLabel: 'VA 21-526 Veterans Application for Compensation or Pension',
          uploadedDateTime: '2024-07-16T18:59:08Z'
        }, {
          documentId: '{c4dbbe82-4502-4a0a-bfec-a65b7ddd2f8f}',
          originalFileName: 'Jesse_Gray_600527334_526EZ.pdf',
          documentTypeLabel: 'VA 21-526 Veterans Application for Compensation or Pension',
          uploadedDateTime: '2024-07-16T18:59:43Z'
        }, {
          documentId: '{3664df4a-5cba-4151-b8ac-eb6d79d4e035}',
          originalFileName: 'Jesse_Gray_600527334_5103.pdf',
          documentTypeLabel: '5103 Notice Acknowledgement',
          trackedItemId: 499_226, uploadedDateTime: '2024-07-17T18:03:50Z'
        }, {
          documentId: '{8a2d0eb9-b181-48ba-a08a-31bb6958e170}',
          originalFileName: 'Jesse_Gray_600527334_5103.pdf',
          documentTypeLabel: '5103 Notice Acknowledgement',
          trackedItemId: 499_226, uploadedDateTime: '2024-07-17T18:20:23Z'
        }, {
          documentId: '{cef55a7b-ccef-44f5-8fe5-9b02d7ea7efb}',
          originalFileName: 'Jesse_Gray_600527334_5103.pdf',
          documentTypeLabel: '5103 Notice Acknowledgement',
          trackedItemId: 499_270, uploadedDateTime: '2024-07-17T19:35:47Z'
        }, {
          documentId: '{3b5b3361-9120-4c37-b842-1a0300b24fb9}',
          originalFileName: 'jesse_gray_600527334_5103_2024-07-17T114958261CDT.pdf',
          documentTypeLabel: '5103 Notice Acknowledgement',
          uploadedDateTime: '2024-07-17T16:50:01Z'
        }
      ]
    } }
  end

  context 'when the claims controller calls the supporting_documents module' do
    let(:controller) { FakeController.new }

    before do
      allow(Flipper).to receive(:enabled?).with(:claims_status_v2_lh_benefits_docs_service_enabled).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_use_birls_id).and_return(false)

      allow(controller.local_bgs_service).to receive(:find_by_ssn).with('796111863')
                                                                  .and_return({ file_nbr: '796111863' })
      allow(controller.benefits_doc_api).to receive(:search).with(
        '8675309',
        '796111863'
      ).and_return(supporting_doc_list)
    end

    describe '#build_supporting_docs' do
      it 'builds and returns the correctly number of docs' do
        result = controller.build_supporting_docs(bgs_claim)
        expect(result.length).to eq(supporting_doc_list[:data][:documents].length)
      end

      it 'builds the correct doc output' do
        result = controller.build_supporting_docs(bgs_claim)
        result[0]

        expect(result[0][:document_id]).to eq(supporting_doc_list[:data][:documents][0][:documentId])
        expect(result[0][:document_type_label]).to eq(supporting_doc_list[:data][:documents][0][:documentTypeLabel])
        expect(result[0][:original_file_name]).to eq(supporting_doc_list[:data][:documents][0][:originalFileName])
        expect(result[0][:tracked_item_id]).to eq(nil)
        expect(result[0][:upload_date]).to eq('2024-07-16')
      end
    end

    describe '#bd_upload_date' do
      it 'properly formats the date when a date is sent' do
        result = controller.bd_upload_date(supporting_doc_list[:data][:documents][0][:uploadedDateTime])

        expect(result).to eq('2024-07-16')
      end

      it 'returns nil if the date is empty' do
        result = controller.bd_upload_date(nil)

        expect(result).to eq(nil)
      end
    end

    describe '#upload_date' do
      it 'properly formats the date when a date is sent' do
        result = controller.upload_date(1_414_781_700_000)

        expect(result).to eq('2014-10-31')
      end

      it 'returns nil if the date is empty' do
        result = controller.upload_date(nil)

        expect(result).to eq(nil)
      end
    end
  end
end
