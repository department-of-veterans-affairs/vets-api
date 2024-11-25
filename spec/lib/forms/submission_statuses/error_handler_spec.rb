# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/error_handler'

describe Forms::SubmissionStatuses::ErrorHandler, feature: :form_submission,
                                                  team_owner: :vfs_authenticated_experience_backend do
  let(:error_handler) { described_class.new }

  it 'parses an error with a message key' do
    response = build_response(401, { 'message' => 'Invalid authentication credentials' })
    expect_error_handling(response, 401, 'Unauthorized', 'Invalid authentication credentials')
  end

  it 'parses an error with a detail key' do
    response = build_response(
      500,
      {
        'title' => 'Internal server error',
        'detail' => 'Internal server error',
        'code' => '500',
        'status' => '500'
      }
    )
    expect_error_handling(response, 500, 'Internal Server Error', 'Internal server error')
  end

  it 'parses an error collection' do
    response = build_response(
      422,
      {
        'errors' => [
          {
            'status' => 422,
            'detail' => 'DOC104 - Upload rejected by upstream system. Processing failed and upload must be resubmitted'
          }
        ]
      }
    )
    expect_error_handling(
      response,
      422,
      'Unprocessable Content',
      'DOC104 - Upload rejected by upstream system. Processing failed and upload must be resubmitted'
    )
  end

  def build_response(status, body)
    OpenStruct.new(status:, body:)
  end

  def expect_error_handling(response, expected_status, expected_title, expected_detail)
    errors = error_handler.handle_error(status: response.status, body: response.body)
    expected_error = error_handler.normalize(
      status: expected_status,
      title: expected_title,
      detail: expected_detail
    )
    expect(errors.first).to eq(expected_error)
  end
end
