# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Serializer do
  let(:info) do
    {
      AllowAttachments: true,
      AllowReplies: true,
      InquiryHasAttachments: false,
      InquiryHasBeenSplit: false,
      CategoryName: 'Veteran Affairs  - Debt',
      CreatedOn: '1/24/2024 11:48:56 PM',
      Id: '9de0b522-13bb-ee11-a81c-001dd804e04a',
      InquiryLevelOfAuthentication: 'Personal',
      InquiryNumber: 'A-20240124-306903',
      InquiryStatus: 'Reopened',
      InquiryTopic: 'Post-9/11 GI Bill (Chapter 33)',
      LastUpdate: '2/29/2024 12:00:00 AM',
      QueueId: '487de9d5-1b6b-eb11-b0b0-001dd8309f34',
      QueueName: 'Buffalo CSR',
      SchoolFacilityCode: '01234',
      SubmitterQuestion: 'test',
      VeteranRelationship: 'GIBillBeneficiary',
      AttachmentNames: [
        {
          Id: '012345',
          Name: 'File A.pdf'
        }
      ]
    }
  end
  let(:inquiry) { AskVAApi::Inquiries::Entity.new(info) }
  let(:response) { described_class.new(inquiry).serializable_hash }
  let(:expected_response) do
    { data: { id: info[:Id],
              type: :inquiry,
              attributes: {
                allow_attachments: info[:AllowAttachments],
                allow_replies: info[:AllowReplies],
                has_attachments: info[:InquiryHasAttachments],
                has_been_split: info[:InquiryHasBeenSplit],
                category_name: 'Veteran Affairs  - Debt',
                created_on: info[:CreatedOn],
                level_of_authentication: info[:InquiryLevelOfAuthentication],
                inquiry_number: info[:InquiryNumber],
                status: info[:InquiryStatus],
                inquiry_topic: info[:InquiryTopic],
                last_update: info[:LastUpdate],
                queue_id: info[:QueueId],
                queue_name: info[:QueueName],
                school_facility_code: info[:SchoolFacilityCode],
                correspondences: nil,
                submitter_question: info[:SubmitterQuestion],
                veteran_relationship: info[:VeteranRelationship],
                attachments: info[:AttachmentNames]
              } } }
  end

  context 'when correspondences is blank' do
    it 'contains the required required attributes (correspondences are nil)' do
      expect(response).to include(expected_response)
    end
  end

  context 'when correspondences is present' do
    let(:file_path) { 'modules/ask_va_api/config/locales/get_replies_mock_data.json' }
    let(:data) { JSON.parse(File.read(file_path), symbolize_names: true)[:Data] }
    let(:correspondences) { [AskVAApi::Correspondences::Entity.new(data.first)] }
    let(:inquiry) { AskVAApi::Inquiries::Entity.new(info, correspondences) }
    let(:response) { described_class.new(inquiry).serializable_hash }

    let(:correspondences_response) do
      { data: [{ id: '1', type: :correspondence,
                 attributes: { message_type: '722310001: Response from VA',
                               created_on: '1/2/23 4:45:45 PM',
                               modified_on: '1/2/23 5:45:45 PM',
                               status_reason: 'Completed/Sent',
                               description: 'Your claim is still In Progress',
                               enable_reply: true,
                               attachments: [{ Id: '12',
                                               Name: 'correspondence_1_attachment.pdf' }] } }] }
    end

    let(:expected_response_with_correspondences) do
      expected_response.deep_merge(
        data: {
          attributes: {
            correspondences: correspondences_response
          }
        }
      )
    end

    it 'contains the required required attributes (correspondences are a hash)' do
      expect(response).to include(expected_response_with_correspondences)
    end
  end
end
