# frozen_string_literal: true

require 'rails_helper'
require 'bd/bd'
require 'bgs_service/person_web_service'

class FakeController
  include ClaimsApi::V2::ClaimsRequests::SupportingDocuments

  def local_bgs_service
    if Flipper.enabled? :claims_api_use_person_web_service
      ClaimsApi::PersonWebService.new(
        external_uid: target_veteran.participant_id,
        external_key: target_veteran.participant_id
      )
    else
      ClaimsApi::LocalBGS.new(
        external_uid: target_veteran.participant_id,
        external_key: target_veteran.participant_id
      )
    end
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

  def request
    { request_id: '222222222' }
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
  let(:bgs_claim) do
    {
      benefit_claim_details_dto: {
        benefit_claim_id: '111111111'
      }
    }
  end
  let(:ssn) { '796111863' }
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
        }
      ]
    } }
  end

  let(:evss_doc_list) do
    {
      'messages' => nil,
      'documents' => [
        {
          'content' => nil,
          'corporate_document_id' => 107_597,
          'tracked_item_id' => nil,
          'document_id' => '{54EF0C16-A9E7-4C3F-B876-B2C7BEC1F834}',
          'document_size' => 0,
          'document_type_code' => 'L478',
          'document_type_id' => '478',
          'document_type_label' => 'Medical'
        }
      ]
    }
  end

  let(:dummy_class) { Class.new { include ClaimsApi::V2::ClaimsRequests::SupportingDocuments } }

  let(:controller) { FakeController.new }
  let(:file_number) { '796111863' }

  before do
    allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_use_birls_id).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return(false)

    allow(controller).to receive(:get_file_number).with('796111863').and_return('796111863')
    allow(controller.benefits_doc_api).to receive(:search).with('8675309', '796111863')
                                                          .and_return(supporting_doc_list)
  end

  describe '#build_supporting_docs from Benefits Documents' do
    it 'builds and returns the correctly number of docs' do
      allow(controller).to receive(:get_file_number).and_return('796111863')
      result = controller.build_supporting_docs(bgs_claim, ssn)
      expect(result.length).to eq(supporting_doc_list[:data][:documents].length)
    end

    it 'builds the correct doc output' do
      allow(controller).to receive(:get_file_number).and_return('796111863')
      result = controller.build_supporting_docs(bgs_claim, ssn)

      expect(result[0][:document_id]).to eq(supporting_doc_list[:data][:documents][0][:documentId])
      expect(result[0][:document_type_label]).to eq(supporting_doc_list[:data][:documents][0][:documentTypeLabel])
      expect(result[0][:original_file_name]).to eq(supporting_doc_list[:data][:documents][0][:originalFileName])
      expect(result[0][:tracked_item_id]).to be_nil
      expect(result[0][:upload_date]).to eq('2024-07-16')
      expect(result[0][:upload_date_time]).to eq('2024-07-16T18:59:08Z')
    end
  end

  describe '#bd_upload_date' do
    it 'properly formats the date when a date is sent' do
      result = controller.bd_upload_date(supporting_doc_list[:data][:documents][0][:uploadedDateTime])
      expect(result).to eq('2024-07-16')
    end

    it 'returns nil if the date is empty' do
      result = controller.bd_upload_date(nil)
      expect(result).to be_nil
    end
  end

  describe '#upload_date' do
    it 'properly formats the date when a date is sent' do
      result = controller.upload_date(1_414_781_700_000)

      expect(result).to eq('2014-10-31')
    end

    it 'returns nil if the date is empty' do
      result = controller.upload_date(nil)
      expect(result).to be_nil
    end
  end

  describe 'when the claims_api_use_person_web_service flipper is on' do
    let(:person_web_service) { instance_double(ClaimsApi::PersonWebService) }

    before do
      allow(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return true
      allow(ClaimsApi::PersonWebService).to receive(:new).with(external_uid: anything,
                                                               external_key: anything)
                                                         .and_return(person_web_service)
      allow(person_web_service).to receive(:find_by_ssn).and_return({ file_nbr: '796111863' })
    end

    it 'calls local bgs services instead of bgs-ext' do
      controller.find_by_ssn(ssn) # rubocop:disable Rails/DynamicFindBy
      expect(person_web_service).to have_received(:find_by_ssn)
    end
  end
end
