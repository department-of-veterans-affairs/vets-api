# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      InquiryHasBeenSplit: true,
      CategoryName: 'Veteran Affairs  - Debt',
      CreatedOn: '8/5/2024 4:51:52 PM',
      Id: 'a6c3af1b-ec8c-ee11-8178-001dd804e106',
      InquiryLevelOfAuthentication: 'Personal',
      InquiryNumber: 'A-123456',
      InquiryStatus: 'In Progress',
      InquiryTopic: 'Cemetery Debt',
      LastUpdate: '1/1/1900',
      QueueId: '9876t54',
      QueueName: 'Debt Management Center',
      SchoolFacilityCode: '0123',
      SubmitterQuestion: 'My question is... ',
      VeteranRelationship: 'self',
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
                                         has_been_split: info[:InquiryHasBeenSplit],
                                         category_name: info[:CategoryName],
                                         created_on: info[:CreatedOn],
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
