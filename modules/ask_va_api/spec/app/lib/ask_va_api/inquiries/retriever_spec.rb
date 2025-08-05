# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Retriever do
  subject(:retriever) do
    described_class.new(user_mock_data:, entity_class: AskVAApi::Inquiries::Entity, icn:)
  end

  let(:icn) { '1013694290V263188' }
  let(:user_mock_data) { false }
  let(:token) { 'Token' }
  let(:redis_client) { instance_double(AskVAApi::RedisClient) }
  let(:correspondence_retriever) { instance_double(AskVAApi::Correspondences::Retriever) }

  def response_body(data)
    {
      Data: data,
      Message: nil,
      ExceptionOccurred: false,
      ExceptionMessage: nil,
      MessageId: SecureRandom.uuid
    }
  end

  def inquiry_data
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
      AttachmentNames: [{ Id: '012345', Name: 'File A.pdf' }]
    }
  end

  before do
    crm_config = Config::Options.new.merge!(
      base_url: 'https://fake.crm.url',
      veis_api_path: 'eis/vagov.lob.ava/api',
      ocp_apim_subscription_key: 'fake-key',
      service_name: 'crm'
    )

    allow(Settings).to receive_messages(
      ask_va_api: double(crm_api: crm_config),
      vsp_environment: 'development'
    )

    allow(Crm::CrmToken).to receive(:new).and_return(double(call: token))

    allow(AskVAApi::RedisClient).to receive(:new).and_return(redis_client)
    allow(redis_client).to receive(:fetch).with('categories_topics_subtopics')
                                          .and_return({ Topics: [{ Name: 'Veteran Affairs  - Debt',
                                                                   Id: '5c524deb-d864-eb11-bb24-000d3a579c45' }] })

    allow(AskVAApi::Correspondences::Retriever).to receive(:new).and_return(correspondence_retriever)
    allow(correspondence_retriever).to receive(:call).and_return([])
  end

  def stub_faraday(endpoint:, payload:, response:)
    allow_any_instance_of(Faraday::Connection).to receive(:public_send)
      .with(:get, endpoint, payload)
      .and_wrap_original do |_method, *_args, &block|
        request = double('request')
        allow(request).to receive(:headers=).with(hash_including('X-VA-ICN' => icn))
        block.call(request)
        instance_double(Faraday::Response, body: response)
      end
  end

  describe '#call' do
    context 'when ICN is given and CRM returns valid inquiries' do
      before do
        stub_faraday(
          endpoint: 'eis/vagov.lob.ava/api/inquiries',
          payload: { organizationName: 'iris-dev' },
          response: response_body([inquiry_data]).to_json
        )
      end

      it 'returns an array of inquiry entities with expected attributes' do
        result = retriever.call

        expect(result).to all(be_a(AskVAApi::Inquiries::Entity))
        expect(result.size).to eq(1)
        expect(result.first.inquiry_number).to eq('A-123456')
        expect(result.first.queue_name).to eq('Debt Management Center')
      end
    end

    context 'when ID is given and CRM returns a single inquiry' do
      let(:id) { 'A-123456' }

      before do
        stub_faraday(
          endpoint: 'eis/vagov.lob.ava/api/inquiries',
          payload: { inquiryNumber: id, organizationName: 'iris-dev' },
          response: response_body([inquiry_data]).to_json
        )
      end

      it 'returns a single inquiry entity' do
        result = retriever.fetch_by_id(id:)

        expect(result).to be_a(AskVAApi::Inquiries::Entity)
        expect(result.inquiry_number).to eq('A-123456')
        expect(result.queue_name).to eq('Debt Management Center')
      end
    end

    context 'when CRM returns error' do
      let(:error_body) do
        {
          Data: nil,
          Message: 'Data Validation: No Inquiries found',
          ExceptionOccurred: true,
          ExceptionMessage: 'Some exception',
          MessageId: SecureRandom.uuid
        }.to_json
      end

      before do
        stub_faraday(
          endpoint: 'eis/vagov.lob.ava/api/Topics',
          payload: anything,
          response: { Data: [] }.to_json
        )

        stub_faraday(
          endpoint: 'eis/vagov.lob.ava/api/inquiries',
          payload: anything,
          response: error_body
        )
      end

      it 'raises a ServiceError when response indicates failure' do
        expect { retriever.call }.to raise_error(ErrorHandler::ServiceError)
      end
    end
  end
end
