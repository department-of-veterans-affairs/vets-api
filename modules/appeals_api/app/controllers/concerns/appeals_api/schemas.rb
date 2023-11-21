# frozen_string_literal: true

module AppealsApi::Schemas
  extend ActiveSupport::Concern

  def headers_schema = form_schemas.schema(headers_schema_name.upcase)
  def form_schema = form_schemas.schema(form_number)

  def validate_headers(headers_hash) = form_schemas.validate!(headers_schema_name.upcase, headers_hash)
  def validate_form_data(data_hash) = form_schemas.validate!(form_number, data_hash)

  private

  def schema_options
    return self.class::SCHEMA_OPTIONS if defined? self.class::SCHEMA_OPTIONS

    raise "Expected SCHEMA_OPTIONS to be defined in #{self.class.name}"
  end

  def api_name = schema_options.fetch(:api_name)
  def schema_version = schema_options.fetch(:schema_version)
  def error_type = schema_options.fetch(:error_type, Common::Exceptions::DetailedSchemaErrors)

  def form_number
    self.class::FORM_NUMBER if defined? self.class::FORM_NUMBER
  end

  def form_schemas = @form_schemas ||= AppealsApi::FormSchemas.new(error_type, schema_version:, api_name:)

  def headers_schema_name
    schema_options.fetch(:headers_schema_name, form_number ? "#{form_number}_HEADERS" : 'HEADERS')
  end
end
