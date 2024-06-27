# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Serializer do
  let(:info) do
    {
      icn: I18n.t('ask_va_api.test_users.test_user_228_icn'),
      Id: 'a6c3af1b-ec8c-ee11-8178-001dd804e106',
      InquiryNumber: 'A-123456',
      InquiryStatus: 'In Progress',
      SubmitterQuestion: 'My question is... ',
      LastUpdate: '1/1/1900',
      InquiryHasAttachments: true,
      InquiryHasBeenSplit: true,
      VeteranRelationship: 'self',
      SchoolFacilityCode: '0123',
      InquiryTopic: 'topic',
      InquiryLevelOfAuthentication: 'Personal',
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
                inquiry_number: info[:InquiryNumber],
                attachments: info[:AttachmentNames],
                correspondences: nil,
                has_attachments: info[:InquiryHasAttachments],
                has_been_split: info[:InquiryHasBeenSplit],
                level_of_authentication: info[:InquiryLevelOfAuthentication],
                last_update: info[:LastUpdate],
                status: info[:InquiryStatus],
                submitter_question: info[:SubmitterQuestion],
                school_facility_code: info[:SchoolFacilityCode],
                topic: info[:InquiryTopic],
                veteran_relationship: info[:VeteranRelationship]
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
                               modified_on: '1/2/23',
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
