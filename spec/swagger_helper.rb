# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/rswag_config'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs e.g.
  # describe '...', openapi_spec: 'modules/claims_api/app/swagger/claims_api/v2/swagger.json'

  mods = [RepresentationManagement, ClaimsApi, AppealsApi]

  # Load each engine’s rswag config file
  mods.each do |m|
    require_relative m::Engine.root.join('spec', 'support', 'rswag_config')
  end

  # Merge base + per-engine configs
  combined = mods
             .map { |m| m::RswagConfig.new.config }
             .reduce({}, :deep_merge)

  config.openapi_specs = RswagConfig.new.config.merge(combined)

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :json
end
