# frozen_string_literal: true

class AppealsApi::Schemas::SharedSchemasController < AppealsApi::ApplicationController
  require 'uri'

  skip_before_action :authenticate
  before_action :check_schema_type

  ACCEPTED_SCHEMA_TYPES = %w[
    address
    nonBlankString
    phone
    timezone
  ].freeze

  FORM_NUMBERS = {
    'notice_of_disagreements' => '10182',
    'higher_level_reviews' => '200996',
    'supplemental_claims' => '200995'
  }.freeze

  def show
    render json: file_as_json
  end

  private

  def uri
    @uri ||= URI(request.path)
  end

  def api_name
    uri.path.split('/')[3].tr('-', '_')
  end

  def api_version
    uri.path.split('/')[4]
  end

  def schema_form_name
    FORM_NUMBERS[api_name] || 'headers'
  end

  def schema_type
    @schema_type ||= params[:schema_type]
  end

  def shared_schemas_file
    Rails.root.join('modules', 'appeals_api', 'config', 'schemas', 'shared', api_version, "#{schema_type}.json")
  end

  def file_as_json
    JSON.parse File.read shared_schemas_file
  end

  def check_schema_type
    unless schema_type.in?(ACCEPTED_SCHEMA_TYPES)
      render json: { errors: [invalid_schema_type_error] },
             status: :not_found
    end
  end

  def invalid_schema_type_error
    {
      title: 'not_found',
      detail: I18n.t('appeals_api.errors.invalid_schema_type', schema_type:),
      code: 'InvalidSchemaType',
      status: '404',
      source: { parameter: schema_type },
      meta: { 'available_options': [schema_form_name] + ACCEPTED_SCHEMA_TYPES }
    }
  end
end
