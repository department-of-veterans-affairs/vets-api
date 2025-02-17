# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      AllowAttachments: true,
      AllowReplies: true,
      InquiryHasAttachments: false,
      InquiryHasBeenSplit: false,
      CategoryId: '75524deb-d864-eb11-bb24-000d3a579c45',
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
  let(:inquiry) { creator.new(info) }

  it 'creates an inquiry' do
    expect(inquiry).to have_attributes({
                                         allow_attachments: info[:AllowAttachments],
                                         allow_replies: info[:AllowReplies],
                                         has_been_split: info[:InquiryHasBeenSplit],
                                         category_name: info[:CategoryName],
                                         created_on: info[:CreatedOn],
                                         has_attachments: info[:InquiryHasAttachments],
                                         id: info[:Id],
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
                                       })
  end
end
