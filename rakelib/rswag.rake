# frozen_string_literal: true

require 'fileutils'

namespace :rswag do
  namespace :claims_api do
    desc 'Generate rswag docs for claims_api'
    task run: :environment do
      ENV['PATTERN'] = 'modules/claims_api/spec/requests/**/*_spec.rb'
      ENV['RAILS_MODULE'] = 'claims_api'
      ENV['SWAGGER_DRY_RUN'] = '0'
      Rake::Task['rswag:specs:swaggerize'].invoke

      %w[v1 v2].each { |version| strip_swagger_base_path(version) }
    end
  end

  namespace :appeals_api do
    desc 'Generate rswag docs and schemas for appeals_api'
    task run: %i[prod]

    task prod: :environment do
      ENV['PATTERN'] = 'modules/appeals_api/spec/docs/'
      ENV['RAILS_MODULE'] = 'appeals_api'
      ENV['SWAGGER_DRY_RUN'] = '0'
      Rake::Task['rswag:specs:swaggerize'].invoke
    end

    task dev: :environment do
      ENV['PATTERN'] = 'modules/appeals_api/spec/docs/'
      ENV['RSWAG_ENV'] = 'dev'
      ENV['RAILS_MODULE'] = 'appeals_api'
      ENV['SWAGGER_DRY_RUN'] = '0'
      ENV['WIP_DOCS_ENABLED'] = Settings.modules_appeals_api.documentation.wip_docs&.join(',') || ''
      Rake::Task['rswag:specs:swaggerize'].invoke
    end
  end
end

def strip_swagger_base_path(version)
  # Rwag still generates `basePath`, which is invalid in OAS v3 (https://github.com/rswag/rswag/issues/318)
  # This removes the basePath value from the generated JSON file(s)
  swagger_file_path = ClaimsApi::Engine.root.join("app/swagger/claims_api/#{version}/swagger.json")
  temp_path = swagger_file_path.sub('swagger.json', 'temp.json').to_s

  File.open(temp_path, 'w') do |output_file|
    File.foreach(swagger_file_path) do |line|
      output_file.puts line unless line.include?('basePath')
    end
  end

  FileUtils.mv(temp_path, swagger_file_path.to_s)
end
