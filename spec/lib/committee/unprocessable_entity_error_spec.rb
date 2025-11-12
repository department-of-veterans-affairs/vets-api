# frozen_string_literal: true

require 'rails_helper'
require 'committee/unprocessable_entity_error'

describe Committee::UnprocessableEntityError do
  # Committee::ValidationError requires: status, id, message (and optional request)
  # status and id are passed to parent, but our class overrides status method
  def build_error(message = 'Test error')
    described_class.new(422, 'error_id', message)
  end

  describe 'inheritance' do
    it 'inherits from Committee::ValidationError' do
      error = build_error
      expect(error).to be_a(Committee::ValidationError)
    end
  end

  describe '#status' do
    it 'returns 422' do
      error = build_error
      expect(error.status).to eq(422)
    end
  end

  describe '#error_body' do
    it 'returns the correct error structure with sanitized message' do
      error = build_error('Validation failed')
      body = error.error_body

      expect(body).to have_key(:errors)
      expect(body[:errors]).to be_an(Array)
      expect(body[:errors].length).to eq(1)

      error_obj = body[:errors].first
      expect(error_obj).to eq(
        title: 'Unprocessable Entity',
        detail: 'Request did not conform to API schema.',
        code: '422',
        status: '422',
        source: 'Committee::Middleware::RequestValidation'
      )
    end

    context 'with different error messages' do
      it 'returns generic message regardless of input to prevent PII exposure' do
        error = build_error('Invalid request parameters')
        body = error.error_body

        expect(body[:errors].first[:detail]).to eq('Request did not conform to API schema.')
      end
    end

    it 'has all required error fields' do
      error = build_error
      body = error.error_body
      error_obj = body[:errors].first

      expect(error_obj.keys).to match_array(%i[title detail code status source])
    end
  end

  describe '#render' do
    it 'returns the correct status' do
      error = build_error
      render_result = error.render

      expect(render_result[0]).to eq(422)
    end

    it 'sets the correct content type header' do
      error = build_error
      render_result = error.render

      expect(render_result[1]).to eq({ 'Content-Type' => 'application/json' })
    end

    it 'includes the JSON-encoded error body with sanitized message' do
      error = build_error('Validation failed')
      render_result = error.render

      expect(render_result[2]).to be_an(Array)
      expect(render_result[2].length).to eq(1)

      parsed_body = JSON.parse(render_result[2].first)
      expect(parsed_body).to have_key('errors')
      expect(parsed_body['errors']).to be_an(Array)
      expect(parsed_body['errors'].first['detail']).to eq('Request did not conform to API schema.')
    end

    it 'returns valid JSON' do
      error = build_error
      render_result = error.render

      expect { JSON.parse(render_result[2].first) }.not_to raise_error
    end

    it 'has all three elements in the response array' do
      error = build_error
      render_result = error.render

      expect(render_result).to be_an(Array)
      expect(render_result.length).to eq(3)
    end
  end

  describe 'integration' do
    it 'can be instantiated and used with a message' do
      message = 'Custom validation error message'
      error = build_error(message)

      expect(error.message).to eq(message)
      expect(error.status).to eq(422)
      expect(error.error_body[:errors].first[:detail]).to eq('Request did not conform to API schema.')
    end
  end

  describe '#sanitize_detail (PII protection)' do
    it 'returns generic message for SSN pattern validation errors to prevent PII exposure' do
      message = 'pattern ^\\d{9}$ does not match value: "123-45-6789", example: 123456789'
      error = build_error(message)
      body = error.error_body

      expect(body[:errors].first[:detail]).to eq('Request did not conform to API schema.')
      expect(body[:errors].first[:detail]).not_to include('123-45-6789')
    end

    it 'returns generic message for OpenAPI validation errors to prevent PII exposure' do
      message = '#/paths/~1v0~1form21p530a~1download_pdf/post/requestBody/content/application~1json/schema/' \
                'properties/veteranInformation/properties/ssn pattern ^\\d{9}$ does not match value: ' \
                '"123-45x6789", example: 123456789'
      error = build_error(message)
      body = error.error_body

      detail = body[:errors].first[:detail]
      expect(detail).to eq('Request did not conform to API schema.')
      expect(detail).not_to include('123-45x6789')
      expect(detail).not_to include('pattern')
      expect(detail).not_to include('#/paths')
    end

    it 'returns generic message for max length validation errors' do
      message = '"USA" is longer than max length'
      error = build_error(message)
      body = error.error_body

      expect(body[:errors].first[:detail]).to eq('Request did not conform to API schema.')
      expect(body[:errors].first[:detail]).not_to include('USA')
    end

    it 'returns generic message for email validation errors' do
      message = 'email address format does not match value: "test@example.com"'
      error = build_error(message)
      body = error.error_body

      expect(body[:errors].first[:detail]).to eq('Request did not conform to API schema.')
      expect(body[:errors].first[:detail]).not_to include('test@example.com')
    end

    it 'returns generic message for any non-blank error to maximize PII protection' do
      message = 'Any validation error message with potential PII'
      error = build_error(message)
      body = error.error_body

      expect(body[:errors].first[:detail]).to eq('Request did not conform to API schema.')
    end
  end
end
