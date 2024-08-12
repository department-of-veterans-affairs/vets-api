# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/error_handler'

describe Forms::SubmissionStatuses::ErrorHandler do
  let(:error_handler) { Forms::SubmissionStatuses::ErrorHandler.new }

  it 'parses an error with a message key' do
    response = OpenStruct.new(status: 401, body: { 'message' => 'Invalid authentication credentials' })

    errors = error_handler.handle_error(response)
    expected_error = error_handler.normalize(
      status: 401,
      title: 'Unauthorized',
      detail: 'Invalid authentication credentials'
    )

    expect(errors.first).to eq(expected_error)
  end

  it 'parses an error with a detail key' do
    response = OpenStruct.new(
      status: 500,
      body: {
        'title' => 'Internal server error',
        'detail' => 'Internal server error',
        'code' => '500',
        'status' => '500'
      }
    )

    errors = error_handler.handle_error(response)
    expected_error = error_handler.normalize(
      status: 500,
      title: 'Internal Server Error',
      detail: 'Internal server error'
    )

    expect(errors.first).to eq(expected_error)
  end

  it 'parses an error collection' do
    response = OpenStruct.new(
      status: 422,
      body: {
        'errors' => [
          {
            'status' => 422,
            'detail' => 'DOC104 - Upload rejected by upstream system. Processing failed and upload must be resubmitted'
          }
        ]
      }
    )

    errors = error_handler.handle_error(response)
    expected_error = error_handler.normalize(
      status: 422,
      title: 'Unprocessable Content',
      detail: 'DOC104 - Upload rejected by upstream system. Processing failed and upload must be resubmitted'
    )

    expect(errors.first).to eq(expected_error)
  end
end
