# frozen_string_literal: true

require 'appeals_api/form_schemas'

class AppealsApi::ContestableIssues::V2::ContestableIssuesController < AppealsApi::ApplicationController
  skip_before_action :authenticate

  FORM_NUMBER = 'CONTESTABLE_ISSUES_HEADERS'
  SCHEMA_ERROR_TYPE = Common::Exceptions::DetailedSchemaErrors

  def schema
    render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(
      AppealsApi::FormSchemas.new(
        SCHEMA_ERROR_TYPE,
        schema_version: 'v2'
      ).schema(self.class::FORM_NUMBER)
    )
  end
end
