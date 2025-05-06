# frozen_string_literal: true

require 'rails_helper'
require AskVAApi::Engine.root.join('spec', 'support', 'shared_contexts.rb')

RSpec.describe AskVAApi::Inquiries::Creator do
  # allow to have access to inquiry_params and translated_payload
  include_context 'shared data'

  let(:icn) { '123456' }
  let(:service) { instance_double(Crm::Service) }
  let(:user) { build(:user, :accountable_with_sec_id, icn: '234', edipi: '123') }
  let(:creator) { described_class.new(service:, user:) }
  let(:file_path) { 'modules/ask_va_api/config/locales/get_inquiries_mock_data.json' }
  let(:base64_encoded_file) { Base64.strict_encode64(File.read(file_path)) }
  let(:file) { "data:image/png;base64,#{base64_encoded_file}" }
  let(:endpoint) { AskVAApi::Inquiries::Creator::ENDPOINT }
  let(:translator) { instance_double(AskVAApi::Translator) }
  let(:cache_data_service) { instance_double(Crm::CacheData) }
  let(:cached_data) do
    data = File.read('modules/ask_va_api/config/locales/get_optionset_mock_data.json')
    JSON.parse(data, symbolize_names: true)
  end
  let(:patsr_facilities) do
    data = File.read('modules/ask_va_api/config/locales/get_facilities_mock_data.json')
    JSON.parse(data, symbolize_names: true)
  end

  before do
    allow(Crm::CacheData).to receive(:new).and_return(cache_data_service)
    allow(cache_data_service).to receive(:call).with(
      endpoint: 'optionset',
      cache_key: 'optionset'
    ).and_return(cached_data)
    allow(cache_data_service).to receive(:fetch_and_cache_data).and_return(patsr_facilities)
    allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
  end

  describe '#call' do
    context 'when the API call is successful' do
      before do
        allow(service).to receive(:call).and_return({
                                                      Data: {
                                                        InquiryNumber: '530d56a8-affd-ee11-a1fe-001dd8094ff1'
                                                      },
                                                      Message: '',
                                                      ExceptionOccurred: false,
                                                      ExceptionMessage: '',
                                                      MessageId: 'b8ebd8e7-3bbf-49c5-aff0-99503e50ee27'
                                                    })
      end

      it 'assigns VeteranICN and posts data to the service' do
        response = creator.call(inquiry_params: inquiry_params[:inquiry])
        expect(response).to eq({ InquiryNumber: '530d56a8-affd-ee11-a1fe-001dd8094ff1' })
      end
    end

    context 'when the API call fails' do
      let(:body) do
        '{"Data":null,"Message":"Data Validation: missing InquiryCategory"' \
          ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: missing' \
          'InquiryCategory","MessageId":"cb0dd954-ef25-4e56-b0d9-41925e5a190c"}'
      end
      let(:expected_context_hash) do
        {
          safe_fields: {
            category_id: '73524deb-d864-eb11-bb24-000d3a579c45',
            contact_preference: 'Email',
            family_members_location_of_residence: 'Alabama',
            is_question_about_veteran_or_someone_else: 'Veteran',
            more_about_your_relationship_to_veteran: 'CHILD',
            relationship_to_veteran: "I'm a family member of a Veteran",
            select_category: 'Health care',
            select_topic: 'Audiology and hearing aids',
            subtopic_id: '',
            topic_id: 'c0da1728-d91f-ed11-b83c-001dd8069009',
            veterans_postal_code: '80122',
            who_is_your_question_about: 'Someone else'
          }
        }
      end
      let(:expected_error) do
        {
          error: 'InquiriesCreatorError: {"Data":null,"Message":"Data Validation: missing InquiryCategory",' \
                 '"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: missingInquiryCategory",' \
                 '"MessageId":"cb0dd954-ef25-4e56-b0d9-41925e5a190c"}'
        }
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow(service).to receive(:call).and_return(failure)
      end

      it 'raises InquiriesCreatorError with safe fields in context' do
        creator.call(inquiry_params: inquiry_params[:inquiry])
      rescue AskVAApi::Inquiries::InquiriesCreatorError => e
        expect(e).to be_a(AskVAApi::Inquiries::InquiriesCreatorError)
        expect(e.context).to eq(expected_context_hash)
        expect(e.message).to eq(expected_error[:error])
      end
    end
  end
end
