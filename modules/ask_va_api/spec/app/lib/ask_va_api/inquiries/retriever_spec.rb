# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Retriever do
  subject(:retriever) do
    described_class.new(user_mock_data:, entity_class: AskVAApi::Inquiries::Entity, icn:)
  end

  def mock_response(status:, body:)
    instance_double(Faraday::Response, status:, body: body.to_json)
  end

  let(:service) { instance_double(Crm::Service) }
  let(:icn) { nil }
  let(:error_message) { 'Some error occurred' }
  let(:user_mock_data) { false }

  before do
    allow(Crm::Service).to receive(:new).and_return(service)
    allow(service).to receive(:call)
  end

  describe '#call' do
    context 'when Crm raise an error' do
      let(:icn) { '123' }
      let(:body) do
        '{"Data":null,"Message":"Data Validation: No Inquiries found by ID A-20240423-30709"' \
          ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: No Inquiries found by ' \
          'ID A-20240423-30709","MessageId":"ca5b990a-63fe-407d-a364-46caffce12c1"}'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
        allow(service).to receive(:call).and_return(failure)
      end

      it 'raise InquiriesRetrieverrError' do
        expect { retriever.call }.to raise_error(ErrorHandler::ServiceError)
      end
    end

    context 'when successful' do
      let(:cache_data) do
        {
          Topics: [
            {
              Name: 'Veteran Affairs  - Debt',
              Id: '5c524deb-d864-eb11-bb24-000d3a579c45',
              ParentId: nil,
              Description: nil,
              RequiresAuthentication: true,
              AllowAttachments: true,
              RankOrder: 4,
              DisplayName: 'Veteran Affairs  - Debt',
              TopicType: 'Category',
              ContactPreferences: []
            }
          ]
        }
      end

      before do
        allow_any_instance_of(AskVAApi::RedisClient).to receive(:fetch)
          .with('categories_topics_subtopics')
          .and_return(cache_data)
      end

      context 'with user_mock_data' do
        context 'when an ID is given' do
          let(:user_mock_data) { true }
          let(:id) { 'A-1' }

          it 'returns an array object with correct data' do
            expect(retriever.fetch_by_id(id:)).to be_a(AskVAApi::Inquiries::Entity)
          end
        end

        context 'when an ICN is given' do
          let(:user_mock_data) { true }
          let(:icn) { '1008709396V637156' }

          it 'returns an array object with correct data' do
            expect(retriever.call.first).to be_a(AskVAApi::Inquiries::Entity)
          end
        end
      end

      context 'with Crm::Service' do
        context 'when an ID is given' do
          let(:id) { '123' }
          let(:response) do
            { Data: [{
              InquiryHasBeenSplit: true,
              CategoryId: '5c524deb-d864-eb11-bb24-000d3a579c45',
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
            }] }
          end

          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
            allow(service).to receive(:call).and_return(response)
          end

          it 'returns an array object with correct data' do
            expect(retriever.fetch_by_id(id:)).to be_a(AskVAApi::Inquiries::Entity)
          end
        end

        context 'when an ICN is given' do
          let(:icn) { '1013694290V263188' }
          let(:response) do
            {
              Data: [
                {
                  InquiryHasBeenSplit: true,
                  CategoryId: '5c524deb-d864-eb11-bb24-000d3a579c45',
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
                },
                {
                  InquiryHasBeenSplit: true,
                  CategoryId: '5c524deb-d864-eb11-bb24-000d3a579c45',
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
                },
                {
                  InquiryHasBeenSplit: true,
                  CategoryId: '5c524deb-d864-eb11-bb24-000d3a579c45',
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
              ],
              Message: nil,
              ExceptionOccurred: false,
              ExceptionMessage: nil,
              MessageId: '3779a3c5-15a5-4846-8198-d499a0bbfe1f'
            }
          end

          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
            allow(service).to receive(:call).and_return(response)
          end

          it 'returns an array object with correct data' do
            expect(retriever.call.first).to be_a(AskVAApi::Inquiries::Entity)
          end
        end
      end

      context 'with Correspondences' do
        let(:id) { '123' }
        let(:response) do
          { Data: [{
            InquiryHasBeenSplit: true,
            CategoryId: '5c524deb-d864-eb11-bb24-000d3a579c45',
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
          }] }
        end

        context 'when Correspondence::Retriever returns an error' do
          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
            allow(service).to receive(:call).and_return(response)
            allow_any_instance_of(AskVAApi::Correspondences::Retriever).to receive(:call)
              .and_return('Data Validation: No Inquiry Found')
          end

          it 'returns correspondences as an empty array' do
            inquiry = retriever.fetch_by_id(id:)

            expect(inquiry.correspondences).to eq([])
          end
        end

        context 'when Correspondence::Retriever returns a success' do
          let(:cor_info) do
            {
              Id: 'f4b12ee3-93bb-ed11-9886-001dd806a6a7',
              ModifiedOn: '3/5/2023 8:25:49 PM',
              StatusReason: 'Sent',
              Description: 'Dear aminul, Thank you for submitting your ' \
                           'Inquiry with the U.S. Department of Veteran Affairs.',
              MessageType: 'Notification',
              EnableReply: true,
              AttachmentNames: nil
            }
          end
          let(:correspondence) { AskVAApi::Correspondences::Entity.new(cor_info) }

          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
            allow(service).to receive(:call).and_return(response)
            allow_any_instance_of(AskVAApi::Correspondences::Retriever).to receive(:call)
              .and_return([correspondence])
          end

          it 'returns correspondences as an empty array' do
            inquiry = retriever.fetch_by_id(id:)

            expect(inquiry.correspondences).to eq([correspondence])
          end
        end
      end
    end
  end
end
