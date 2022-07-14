# frozen_string_literal: true

class AppealsApi::Schemas::SharedSchemasController < AppealsApi::ApplicationController
  require 'uri'

  skip_before_action :authenticate
  before_action :check_schema_type

  ACCEPTED_SCHEMA_TYPES = %w[
    non_blank_string
    address
    date
    phone
    timezone
  ].freeze

  def show
    render json: file_as_json
  end

  private

  def uri
    @uri ||= URI(request.path)
  end

  def appeal_type_with_version
    "#{uri.path.split('/')[3]}_#{uri.path.split('/')[4]}"
  end

  def schema_version
    {
      'notice_of_disagreements_v1' => 'v1',
      'notice_of_disagreements_v2' => 'v1',
      'higher_level_reviews_v2' => 'v1',
      'supplemental_claims_v2' => 'v1'
    }[appeal_type_with_version]
  end

  def schema_type
    @schema_type ||= params[:schema_type]
  end

  def shared_schemas_file
    Rails.root.join('modules', 'appeals_api', 'config', 'schemas', 'shared', schema_version, "#{schema_type}.json")
  end

  def file_as_json
    JSON.parse File.read shared_schemas_file
  end

  def check_schema_type
    render json: invalid_schema_type_error, status: :not_found unless schema_type.in?(ACCEPTED_SCHEMA_TYPES)
  end

  def invalid_schema_type_error
    {
      title: 'not_found',
      detail: I18n.t('appeals_api.errors.invalid_schema_type', schema_type: schema_type),
      code: 'InvalidSchemaType',
      status: '404',
      source: { parameter: schema_type },
      meta: ACCEPTED_SCHEMA_TYPES
    }
  end
end
