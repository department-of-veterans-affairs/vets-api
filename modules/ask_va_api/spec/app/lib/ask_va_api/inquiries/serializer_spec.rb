# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Serializer do
  let(:info) do
    {
      icn: '1008709396V637156',
      id: 'a6c3af1b-ec8c-ee11-8178-001dd804e106',
      inquiryNumber: 'A-123456',
      inquiryStatus: 'In Progress',
      submitterQuestion: 'My question is... ',
      lastUpdate: '1/1/1900',
      inquiryHasAttachments: true,
      inquiryHasBeenSplit: true,
      veteranRelationship: 'self',
      schoolFacilityCode: '0123',
      inquiryTopic: 'topic',
      inquiryLevelOfAuthentication: 'Personal',
      attachmentNames: [
        {
          id: '012345',
          name: 'File A.pdf'
        }
      ]
    }
  end
  let(:inquiry) { AskVAApi::Inquiries::Entity.new(info) }
  let(:response) { described_class.new(inquiry) }
  let(:expected_response) do
    { data: { id: info[:id],
              type: :inquiry,
              attributes: {
                inquiry_number: info[:inquiryNumber],
                attachments: info[:attachmentNames],
                correspondences: nil,
                has_attachments: info[:inquiryHasAttachments],
                has_been_split: info[:inquiryHasBeenSplit],
                level_of_authentication: info[:inquiryLevelOfAuthentication],
                last_update: info[:lastUpdate],
                status: info[:inquiryStatus],
                submitter_question: info[:submitterQuestion],
                school_facility_code: info[:schoolFacilityCode],
                topic: info[:inquiryTopic],
                veteran_relationship: info[:veteranRelationship]
              } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
