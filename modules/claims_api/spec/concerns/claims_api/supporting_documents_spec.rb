# frozen_string_literal: true

require 'rails_helper'
require 'bd/bd'

class FakeController
  include ClaimsApi::V2::ClaimsRequests::SupportingDocuments

  # def benefits_doc_api
  #   # Mocked behavior for the `benefits_doc_api` method
  #   double(search: { data: { 'documents' => supporting_document_data } })
  # end

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

  def claims_v2_logging(tag = 'traceability', level: :info, message: nil)
    true
  end

  def params
    { id: '8675309' }
  end
end

describe ClaimsApi::V2::ClaimsRequests::SupportingDocuments do
  let(:bgs_claim) {
    {
      :"xmlns:ns0"=>"http://claimstatus.services.ebenefits.vba.va.gov/", 
      :benefit_claim_details_dto=>{
        :attention_needed=>"Yes", 
        :base_end_prdct_type_cd=>"400", 
        :benefit_claim_id=>"600527334", 
        :bnft_claim_lc_status=>{
          :phase_chngd_dt=>"2024-07-16T13:58:51", 
          :phase_type=>"Complete", 
          :phase_type_change_ind=>"78"
        }, 
        :bnft_claim_type_cd=>"400SUPP", 
        :claim_complete_dt=>"2024-07-16T13:58:51", 
        :claim_dt=>"2024-07-16", 
        :claim_status=>"CAN", 
        :claim_status_type=>"Compensation", 
        :contentions=>"diabetes, type 1 or type 2 (New)", 
        :decision_notification_sent=>"No", 
        :development_letter_sent=>"Yes", 
        :end_prdct_type_cd=>"401", 
        :filed5103_waiver_ind=>"Y", 
        :poa=>"GEORGIA DEPARTMENT OF VETERAN SERVICE", 
        :program_type=>"CPL", 
        :ptcpnt_clmant_id=>"600045026", 
        :ptcpnt_vet_id=>"600045026", 
        :regional_office_jrsdctn=>"National Work Queue", 
        :submtr_applcn_type_cd=>"VBMS", 
        :submtr_role_type_cd=>"VBA", 
        :temp_regional_office_jrsdctn=>"St. Petersburg", 
        :wsyswwn=>{
          :address_line1=>"National Work Queue", 
          :address_line2=>"810 Vermont Avenue NW", 
          :address_line3=>nil, 
          :city=>"Washington", 
          :state=>"DC", 
          :zip=>"20420"
        }, 
        :wwsnfy=>[
          {
            :date_open=>"2024-07-17", 
            :dvlpmt_item_id=>"499270", 
            :items=>"Text in here", 
            :suspense_dt=>"2024-08-16"
          }, {
            :date_open=>"2024-07-17", 
            :dvlpmt_item_id=>"499226", 
            :items=>"More text in here", 
            :suspense_dt=>"2024-08-16"
          }
        ]
      }
    }
  }

  let(:supporting_doc_list) {
    {:data=>{:documents=>[{:documentId=>"{2161bfaa-cb21-43a6-90fc-c800c88f1234}", :originalFileName=>"Jesse_Gray_600527334_526EZ.pdf", :documentTypeLabel=>"VA 21-526 Veterans Application for Compensation or Pension", :uploadedDateTime=>"2024-07-16T18:59:08Z"}, {:documentId=>"{c4dbbe82-4502-4a0a-bfec-a65b7ddd2f8f}", :originalFileName=>"Jesse_Gray_600527334_526EZ.pdf", :documentTypeLabel=>"VA 21-526 Veterans Application for Compensation or Pension", :uploadedDateTime=>"2024-07-16T18:59:43Z"}, {:documentId=>"{3664df4a-5cba-4151-b8ac-eb6d79d4e035}", :originalFileName=>"Jesse_Gray_600527334_5103.pdf", :documentTypeLabel=>"5103 Notice Acknowledgement", :trackedItemId=>499226, :uploadedDateTime=>"2024-07-17T18:03:50Z"}, {:documentId=>"{8a2d0eb9-b181-48ba-a08a-31bb6958e170}", :originalFileName=>"Jesse_Gray_600527334_5103.pdf", :documentTypeLabel=>"5103 Notice Acknowledgement", :trackedItemId=>499226, :uploadedDateTime=>"2024-07-17T18:20:23Z"}, {:documentId=>"{cef55a7b-ccef-44f5-8fe5-9b02d7ea7efb}", :originalFileName=>"Jesse_Gray_600527334_5103.pdf", :documentTypeLabel=>"5103 Notice Acknowledgement", :trackedItemId=>499270, :uploadedDateTime=>"2024-07-17T19:35:47Z"}, {:documentId=>"{3b5b3361-9120-4c37-b842-1a0300b24fb9}", :originalFileName=>"jesse_gray_600527334_5103_2024-07-17T114958261CDT.pdf", :documentTypeLabel=>"5103 Notice Acknowledgement", :uploadedDateTime=>"2024-07-17T16:50:01Z"}]}}
  }

  context 'when the claims controller calls the supporting_documents module' do
    let(:controller) { FakeController.new }

    before do
      allow(Flipper).to receive(:enabled?).with(:claims_status_v2_lh_benefits_docs_service_enabled).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_use_birls_id).and_return(false)

      allow(controller.local_bgs_service).to receive(:find_by_ssn).with('796111863').and_return({ file_nbr: '796111863' })
      allow(controller.benefits_doc_api).to receive(:search).with(
        '8675309',
        '796111863'
      ).and_return(supporting_doc_list)
    end

    it 'successfully builds the supporting documents from the bgs claim' do
      result = controller.build_supporting_docs(bgs_claim)

      byebug
    end
  end
end