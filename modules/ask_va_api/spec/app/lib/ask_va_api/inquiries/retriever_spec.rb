# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Retriever do
  subject(:retriever) do
    described_class.new(user_mock_data:, entity_class: AskVAApi::Inquiries::Entity, icn:)
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
      let(:failure) do
        {
          status: 400,
          body:,
          response_headers: nil,
          url: nil
        }
      end

      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
        allow(service).to receive(:call).and_return(failure)
      end

      it 'raise CorrespondenceRetrieverrError' do
        expect { retriever.call }.to raise_error(ErrorHandler::ServiceError)
      end
    end

    context 'when successful' do
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
            { Data: [{ Id: '154163f2-8fbb-ed11-9ac4-00155da17a6f',
                       InquiryNumber: 'A-20230305-306178',
                       InquiryStatus: 'Reopened',
                       SubmitterQuestion: 'test',
                       LastUpdate: '4/1/2024 12:00:00 AM',
                       InquiryHasAttachments: true,
                       InquiryHasBeenSplit: true,
                       VeteranRelationship: 'GIBillBeneficiary',
                       SchoolFacilityCode: '77a51029-6816-e611-9436-0050568d743d',
                       InquiryTopic: 'Medical Care Concerns at a VA Medical Facility',
                       InquiryLevelOfAuthentication: 'Unauthenticated',
                       AttachmentNames: [{ Id: '367e8d31-6c82-1d3c-81b8-dd2cabed7555',
                                           Name: 'Test.txt' }] }] }
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
                  Id: '154163f2-8fbb-ed11-9ac4-00155da17a6f',
                  InquiryNumber: 'A-20230305-306178',
                  InquiryStatus: 'Reopened',
                  SubmitterQuestion: 'test',
                  LastUpdate: '4/1/2024 12:00:00 AM',
                  InquiryHasAttachments: true,
                  InquiryHasBeenSplit: true,
                  VeteranRelationship: 'GIBillBeneficiary',
                  SchoolFacilityCode: '77a51029-6816-e611-9436-0050568d743d',
                  InquiryTopic: 'Medical Care Concerns at a VA Medical Facility',
                  InquiryLevelOfAuthentication: 'Unauthenticated',
                  AttachmentNames: [
                    {
                      Id: '367e8d31-6c82-1d3c-81b8-dd2cabed7555',
                      Name: 'Test.txt'
                    }
                  ]
                },
                {
                  Id: 'b24e8113-92d1-ed11-9ac4-00155da17a6f',
                  InquiryNumber: 'A-20230402-306218',
                  InquiryStatus: 'New',
                  SubmitterQuestion: 'test',
                  LastUpdate: '1/1/0001 12:00:00 AM',
                  InquiryHasAttachments: false,
                  InquiryHasBeenSplit: false,
                  VeteranRelationship: nil,
                  SchoolFacilityCode: '77a51029-6816-e611-9436-0050568d743d',
                  InquiryTopic: 'Medical Care Concerns at a VA Medical Facility',
                  InquiryLevelOfAuthentication: 'Personal',
                  AttachmentNames: nil
                },
                {
                  Id: 'e1ce6ae6-40ec-ee11-904d-001dd8306a72',
                  InquiryNumber: 'A-20240327-307060',
                  InquiryStatus: 'New',
                  SubmitterQuestion: 'test',
                  LastUpdate: '3/27/2024 12:00:00 AM',
                  InquiryHasAttachments: true,
                  InquiryHasBeenSplit: true,
                  VeteranRelationship: nil,
                  SchoolFacilityCode: nil,
                  InquiryTopic: 'Filing for compensation benefits',
                  InquiryLevelOfAuthentication: 'Personal',
                  AttachmentNames: nil
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
          { Data: [{ Id: '154163f2-8fbb-ed11-9ac4-00155da17a6f',
                     InquiryNumber: 'A-20230305-306178',
                     InquiryStatus: 'Reopened',
                     SubmitterQuestion: 'test',
                     LastUpdate: '4/1/2024 12:00:00 AM',
                     InquiryHasAttachments: true,
                     InquiryHasBeenSplit: true,
                     VeteranRelationship: 'GIBillBeneficiary',
                     SchoolFacilityCode: '77a51029-6816-e611-9436-0050568d743d',
                     InquiryTopic: 'Medical Care Concerns at a VA Medical Facility',
                     InquiryLevelOfAuthentication: 'Unauthenticated',
                     AttachmentNames: [{ Id: '367e8d31-6c82-1d3c-81b8-dd2cabed7555',
                                         Name: 'Test.txt' }] }] }
        end

        context 'when Correspondence::Retriever returns an error' do
          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
            allow(service).to receive(:call).and_return(response)
            allow_any_instance_of(AskVAApi::Correspondences::Retriever).to receive(:call)
              .and_return({ Data: [],
                            Message: 'Data Validation: No Inquiry Found',
                            ExceptionOccurred: true,
                            ExceptionMessage: 'Data Validation: No Inquiry Found',
                            MessageId: '2d746074-9e5c-4987-a894-e3f834b156b5' })
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
