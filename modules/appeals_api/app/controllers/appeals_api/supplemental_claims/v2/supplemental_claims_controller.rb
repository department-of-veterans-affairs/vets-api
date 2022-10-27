# frozen_string_literal: true

require 'appeals_api/form_schemas'

class AppealsApi::SupplementalClaims::V2::SupplementalClaimsController < AppealsApi::ApplicationController
  skip_before_action :authenticate

  FORM_NUMBER = '200995_WITH_SHARED_REFS'
  SCHEMA_ERROR_TYPE = Common::Exceptions::DetailedSchemaErrors

  def schema
    response = AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(
      AppealsApi::FormSchemas.new(
        SCHEMA_ERROR_TYPE,
        schema_version: 'v2'
      ).schema(self.class::FORM_NUMBER)
    )

    render json: response
  end
end
