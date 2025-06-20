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
  let(:span) { instance_double('Datadog::Tracing::Span') }

  before do
    allow(Crm::CacheData).to receive(:new).and_return(cache_data_service)
    allow(cache_data_service).to receive(:call).with(
      endpoint: 'optionset',
      cache_key: 'optionset'
    ).and_return(cached_data)
    allow(cache_data_service).to receive(:fetch_and_cache_data).and_return(patsr_facilities)
    allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
  end

  describe '#initialize' do
    context 'when service is provided' do
      let(:custom_service) { instance_double(Crm::Service) }
      let(:creator_with_service) { described_class.new(service: custom_service, user:) }

      it 'uses the provided service' do
        expect(creator_with_service.service).to eq(custom_service)
      end
    end

    context 'when service is not provided' do
      let(:creator_without_service) { described_class.new(user:) }

      it 'creates a default service with user ICN' do
        expect(Crm::Service).to receive(:new).with(icn: user.icn)
        creator_without_service
      end
    end

    context 'when user is nil' do
      let(:creator_nil_user) { described_class.new(user: nil) }

      it 'creates a default service with nil ICN' do
        expect(Crm::Service).to receive(:new).with(icn: nil)
        creator_nil_user
      end
    end
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
        allow(Datadog::Tracing).to receive(:trace).and_yield(span)
        allow(span).to receive(:set_tag)

        response = creator.call(inquiry_params: inquiry_params[:inquiry])
        expect(response).to eq({ InquiryNumber: '530d56a8-affd-ee11-a1fe-001dd8094ff1' })
      end

      it 'does not include ICN or other PII in Datadog tags' do
        expect(Datadog::Tracing).to receive(:trace).with('ask_va_api.inquiries.creator.call').and_yield(span)

        # Verify that ICN is never set as a tag
        expect(span).not_to receive(:set_tag).with('icn', anything)
        expect(span).not_to receive(:set_tag).with('user.icn', anything)

        # Verify safe fields don't contain PII
        expect(span).to receive(:set_tag).with('inquiry_context', anything) do |_key, value|
          expect(value.keys).not_to include(:icn, :ssn, :social_security_number, :date_of_birth)
          expect(value.values.join).not_to match(/\d{3}-\d{2}-\d{4}/) # SSN pattern
          expect(value.values.join).not_to match(/\d{9}/) # ICN pattern
        end

        allow(span).to receive(:set_tag)
        creator.call(inquiry_params: inquiry_params[:inquiry])
      end

      it 'traces the call with Datadog and sets appropriate tags' do
        expect(Datadog::Tracing).to receive(:trace).with('ask_va_api.inquiries.creator.call').and_yield(span)
        expect(span).to receive(:set_tag).with('user.isAuthenticated', true)
        expect(span).to receive(:set_tag).with('user.loa', anything)
        expect(span).to receive(:set_tag).with('inquiry_context', anything)

        creator.call(inquiry_params: inquiry_params[:inquiry])
      end
    end

    context 'user authentication states' do
      let(:basic_inquiry_params) do
        {
          select_category: 'Health care',
          files: [{ file_name: nil, file_content: nil }]
        }
      end

      context 'when user is nil' do
        let(:creator) { described_class.new(service:, user: nil) }

        it 'sets user.isAuthenticated to false when user is nil' do
          allow(service).to receive(:call).and_return({ Data: { InquiryNumber: 'test-123' } })

          expect(Datadog::Tracing).to receive(:trace).and_yield(span)
          expect(span).to receive(:set_tag).with('user.isAuthenticated', false)
          expect(span).to receive(:set_tag).with('user.loa', nil)
          allow(span).to receive(:set_tag) # for other tags
          allow(span).to receive(:set_error) # in case of errors

          creator.call(inquiry_params: basic_inquiry_params)
        end
      end

      context 'when user exists but has no LOA' do
        let(:user_without_loa) { build(:user, :accountable_with_sec_id, icn: '234', edipi: '123') }
        let(:creator) { described_class.new(service:, user: user_without_loa) }

        before do
          allow(user_without_loa).to receive(:loa).and_return({})
        end

        it 'handles missing LOA gracefully' do
          allow(service).to receive(:call).and_return({ Data: { InquiryNumber: 'test-123' } })

          expect(Datadog::Tracing).to receive(:trace).and_yield(span)
          expect(span).to receive(:set_tag).with('user.isAuthenticated', true)
          expect(span).to receive(:set_tag).with('user.loa', nil)
          allow(span).to receive(:set_tag) # for other tags
          allow(span).to receive(:set_error) # in case of errors

          creator.call(inquiry_params: basic_inquiry_params)
        end
      end
    end

    context 'safe fields filtering' do
      let(:unsafe_params) do
        {
          select_category: 'Health care',
          select_topic: 'Safe topic',
          icn: '1234567890',
          ssn: '123-45-6789',
          social_security_number: '987654321',
          date_of_birth: '1990-01-01',
          some_unsafe_field: 'sensitive data',
          files: [{ file_name: nil, file_content: nil }]
        }
      end

      it 'only includes SAFE_INQUIRY_FIELDS in inquiry_context tag' do
        allow(service).to receive(:call).and_return({
                                                      Data: { InquiryNumber: 'test-123' }
                                                    })

        expect(Datadog::Tracing).to receive(:trace).and_yield(span)
        expect(span).to receive(:set_tag).with('inquiry_context', {
                                                 select_category: 'Health care',
                                                 select_topic: 'Safe topic'
                                               })
        allow(span).to receive(:set_tag) # for other tags
        allow(span).to receive(:set_error) # in case of errors

        creator.call(inquiry_params: unsafe_params)
      end

      it 'filters out all unsafe fields from inquiry_context' do
        allow(service).to receive(:call).and_return({
                                                      Data: { InquiryNumber: 'test-123' }
                                                    })

        expect(Datadog::Tracing).to receive(:trace).and_yield(span)
        expect(span).to receive(:set_tag).with('inquiry_context', anything) do |_key, value|
          # Ensure no PII fields are present
          unsafe_fields = %i[icn ssn social_security_number date_of_birth some_unsafe_field]
          expect(value.keys & unsafe_fields).to be_empty
        end
        allow(span).to receive(:set_tag) # for other tags
        allow(span).to receive(:set_error) # in case of errors

        creator.call(inquiry_params: unsafe_params)
      end
    end

    context 'when the API call fails' do
      let(:body) do
        '{"Data":null,"Message":"Data Validation: missing InquiryCategory"' \
          ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: missing' \
          'InquiryCategory","MessageId":"cb0dd954-ef25-4e56-b0d9-41925e5a190c"}'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow(service).to receive(:call).and_return(failure)
      end

      it 'raises InquiriesCreatorError with proper error message' do
        allow(Datadog::Tracing).to receive(:trace).and_yield(span)
        allow(span).to receive(:set_tag)
        allow(span).to receive(:set_error)

        expect { creator.call(inquiry_params: inquiry_params[:inquiry]) }.to raise_error(
          AskVAApi::Inquiries::InquiriesCreatorError,
          /InquiriesCreatorError: .*Data Validation: missing InquiryCategory/
        )
      end

      it 'sets error on Datadog span when exception occurs' do
        expect(Datadog::Tracing).to receive(:trace).with('ask_va_api.inquiries.creator.call').and_yield(span)
        expect(span).to receive(:set_tag).with('user.isAuthenticated', true)
        expect(span).to receive(:set_tag).with('user.loa', anything)
        expect(span).to receive(:set_tag).with('inquiry_context', anything)
        expect(span).to receive(:set_error).with(anything)

        expect { creator.call(inquiry_params: inquiry_params[:inquiry]) }.to raise_error(
          AskVAApi::Inquiries::InquiriesCreatorError
        )
      end
    end

    context 'edge cases and error handling' do
      it 'handles non-hash response from service gracefully' do
        non_hash_response = 'string response'
        allow(service).to receive(:call).and_return(non_hash_response)
        allow(Datadog::Tracing).to receive(:trace).and_yield(span)
        allow(span).to receive(:set_tag)
        allow(span).to receive(:set_error)

        expect { creator.call(inquiry_params: inquiry_params[:inquiry]) }.to raise_error(
          AskVAApi::Inquiries::InquiriesCreatorError,
          /InquiriesCreatorError: undefined method.*body.*for an instance of String/
        )
      end

      it 'handles empty inquiry_params' do
        empty_params = { files: [{ file_name: nil, file_content: nil }] }
        allow(service).to receive(:call).and_return({ Data: { InquiryNumber: 'test-123' } })

        expect(Datadog::Tracing).to receive(:trace).and_yield(span)
        expect(span).to receive(:set_tag).with('inquiry_context', {})
        allow(span).to receive(:set_tag) # for other tags
        allow(span).to receive(:set_error) # in case of errors

        creator.call(inquiry_params: empty_params)
      end

      it 'handles inquiry_params with only unsafe fields' do
        unsafe_only_params = {
          icn: '123',
          ssn: '456',
          files: [{ file_name: nil, file_content: nil }]
        }
        allow(service).to receive(:call).and_return({ Data: { InquiryNumber: 'test-123' } })

        expect(Datadog::Tracing).to receive(:trace).and_yield(span)
        expect(span).to receive(:set_tag).with('inquiry_context', {})
        allow(span).to receive(:set_tag) # for other tags
        allow(span).to receive(:set_error) # in case of errors

        creator.call(inquiry_params: unsafe_only_params)
      end
    end
  end
end
