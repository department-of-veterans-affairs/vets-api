# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sentry::Processor::FilterRequestBody do
  context 'with PII in the [:request][:data] hash' do
    before do
      client = double('client')
      @processor = Sentry::Processor::FilterRequestBody.new(client)
    end

    it 'filters PII for a controller found in FILTERED_CONTROLLER' do
      sentry_request = create_sentry_request_with_pii(controller: 'ppiu')
      result = @processor.process(sentry_request)

      expect(result['request']['data']).to eql(Sentry::Processor::PIISanitizer::FILTER_MASK)
    end

    it 'does not filter PII for a contoller not included in FILTERED_CONTROLLER' do
      sentry_request = create_sentry_request_with_pii(controller: 'another_controller')

      result = @processor.process(sentry_request)

      expect(result['request']['data']).not_to eql(Sentry::Processor::PIISanitizer::FILTER_MASK)
      expect(result['request']['data']).to eql("{\n  \"account_type\": \"Checking\"}")
    end

    it 'works when there is no request body' do
      sentry_request =
        {
          'tags' => {
            'controller_name' => 'ppiu',
            'sign_in_method' => { 'service_name' => 'idme', 'acct_type' => nil }
          },
          'request' => {}
        }
      result = @processor.process(sentry_request)

      expect(result['request']['data']).to be(nil)
    end
  end

  private

  def create_sentry_request_with_pii(controller: 'default')
    {
      'tags' => {
        'controller_name' => controller,
        'sign_in_method' => { 'service_name' => 'idme', 'acct_type' => nil }
      },
      'request' => {
        'data' => "{\n  \"account_type\": \"Checking\"}"
      }
    }
  end
end
