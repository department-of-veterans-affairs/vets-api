# frozen_string_literal: true

class AppealsApi::V1::ContestableIssuesControllerSwagger
  include Swagger::Blocks

  read_file = ->(path) { File.read(AppealsApi::Engine.root.join(*path)) }
  read_json = ->(path) { JSON.parse(read_file.call(path)) }
  read_json_from_same_dir = ->(filename) { read_json.call(['app', 'swagger', 'appeals_api', 'v1', filename]) }

  swagger_path '/contestable_issues' do
    operation :get, tags: ['Issues'] do
      key :summary, 'Returns all contestable issues for a specific veteran.'
      desc = 'Returns all issues a Veteran could contest in a Decision Review as of the `receiptDate`. ' \
        'Associate these results when creating new Decision Reviews.'
      key :description, desc
      parameter name: 'X-VA-SSN', 'in': 'header', required: true, description: 'veteran\'s ssn' do
        schema '$ref': 'X-VA-SSN'
      end
      parameter name: 'X-VA-Receipt-Date', 'in': 'header', required: true do
        desc = '(yyyy-mm-dd) In order to determine contestability of issues, ' \
          'the receipt date of a hypothetical Decision Review must be specified.'
        key :description, desc
        schema type: :string, 'format': :date
      end
      key :responses, read_json_from_same_dir['responses_contestable_issues.json']
    end
  end
end
