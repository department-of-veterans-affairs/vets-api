# frozen_string_literal: true

module AppealsApi
  module V1
    class ContestableIssuesControllerSwagger
      include Swagger::Blocks

      read_file = lambda do |path|
        File.read(AppealsApi::Engine.root.join(*path))
      end

      read_json = lambda do |path|
        JSON.parse(read_file.call(path))
      end

      read_json_from_same_dir = lambda do |filename|
        read_json.call(['app', 'swagger', 'appeals_api', 'v1', filename])
      end

      swagger_path '/contestable_issues' do
        operation :get do
          key :summary, 'Returns all contestable issues for a specific veteran.'
          key(
            :description,
            [
              'Returns all issues a Veteran could contest in a Decision Review',
              'as of the `receiptDate`.  Associate these results when creating',
              'new Decision Reviews.'
            ].join(' ')
          )
          key :tags, ['Issues']
          parameter do
            key :name, 'X-VA-SSN'
            key :in, 'header'
            key :required, true
            key :description, 'veteran\'s ssn'
            schema { key :'$ref', :HlrCreateParameterSsn }
          end
          parameter do
            key :name, 'X-VA-Receipt-Date'
            key :in, 'header'
            key :required, true
            key(
              :description,
              '(yyyy-mm-dd) In order to determine contestability of issues, the receipt date' \
              ' of a hypothetical Decision Review must be supplied.'
            )
            schema do
              key :type, :string
              key :format, :date
            end
          end
          key :responses, read_json_from_same_dir['responses_contestable_issues.json']
        end
      end
    end
  end
end
