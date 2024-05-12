# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Serializer do
  let(:info) do
    {
      icn: I18n.t('ask_va_api')[:test_users][:test_user_228_icn],
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
  let(:response) { described_class.new(inquiry) }
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

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
