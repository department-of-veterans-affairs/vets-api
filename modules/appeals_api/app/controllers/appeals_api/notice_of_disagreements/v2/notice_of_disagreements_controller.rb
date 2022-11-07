# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::NoticeOfDisagreements::V2
  class NoticeOfDisagreementsController < AppealsApi::V2::DecisionReviews::NoticeOfDisagreementsController
    include AppealsApi::OpenidAuth

    FORM_NUMBER = '10182_WITH_SHARED_REFS'
    HEADERS = JSON.parse(
      File.read(
        AppealsApi::Engine.root.join('config/schemas/v2/10182_with_shared_refs_headers.json')
      )
    )['definitions']['nodCreateParameters']['properties'].keys

    def schema
      response = AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(
        AppealsApi::FormSchemas.new(
          SCHEMA_ERROR_TYPE,
          schema_version: 'v2'
        ).schema(self.class::FORM_NUMBER)
      )

      response.tap do |s|
        s.dig(*%w[properties data properties attributes properties]).delete('claimant')
      end

      render json: response
    end
  end
end
