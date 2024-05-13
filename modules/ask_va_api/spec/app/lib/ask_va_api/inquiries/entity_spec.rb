# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      Icn: I18n.t('ask_va_api')[:test_users][:test_user_228_icn],
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
  let(:inquiry) { creator.new(info) }

  it 'creates an inquiry' do
    expect(inquiry).to have_attributes({
                                         id: info[:Id],
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
                                       })
  end
end
