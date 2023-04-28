# frozen_string_literal: true

class AppealsApi::Schemas::SharedSchemasController < AppealsApi::ApplicationController
  require 'uri'

  skip_before_action :authenticate
  before_action :check_schema_type

  ACCEPTED_SCHEMA_TYPES = %w[
    address
    non_blank_string
    phone
    timezone
  ].freeze

  SCHEMA_METADATA = {
    'contestable_issues_v0' => { shared_schema_version: 'v1', form: 'headers' },
    'legacy_appeals_v0' => { shared_schema_version: 'v1', form: 'headers' },
    'notice_of_disagreements_v1' => { shared_schema_version: 'v1', form: '10182' },
    'notice_of_disagreements_v0' => { shared_schema_version: 'v1', form: '10182' },
    'higher_level_reviews_v0' => { shared_schema_version: 'v1', form: '200996' },
    'supplemental_claims_v0' => { shared_schema_version: 'v1', form: '200995' }
  }.freeze

  def show
    render json: file_as_json
  end

  private

  def uri
    @uri ||= URI(request.path)
  end

  def appeal_type_with_version
    "#{uri.path.split('/')[3]}_#{uri.path.split('/')[4]}".tr('-', '_')
  end

  def schema_version
    SCHEMA_METADATA[appeal_type_with_version][:shared_schema_version]
  end

  def schema_form
    SCHEMA_METADATA[appeal_type_with_version][:form]
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
      meta: { 'available_options': [schema_form] + ACCEPTED_SCHEMA_TYPES }
    }
  end
end
