# frozen_string_literal: true

require 'fileutils'

APPEALS_API_DOCS_DIR = 'modules/appeals_api/spec/docs/v2'
APPEALS_API_SECTION_SLUGS = Dir["#{APPEALS_API_DOCS_DIR}/*.rb"]
                            .map { |file_name| file_name.split('/').last.gsub(/_spec.rb$/, '') }

def generate_swagger_doc(dev: false, section: nil)
  ENV['PATTERN'] = section ? "#{APPEALS_API_DOCS_DIR}/#{section}_spec.rb" : APPEALS_API_DOCS_DIR
  ENV['RAILS_MODULE'] = 'appeals_api'
  ENV['SWAGGER_DRY_RUN'] = '0'
  ENV['RSWAG_SECTION_SLUG'] = section unless section.nil?
  if dev
    ENV['RSWAG_ENV'] = 'dev'
    ENV['WIP_DOCS_ENABLED'] = Settings.modules_appeals_api.documentation.wip_docs&.join(',') || ''
  end
  Rake::Task['rswag:specs:swaggerize'].invoke

  # Do rswag-to-oas conversion on output files
  glob = dev ? '_dev' : ''
  glob = section.present? ? "_#{section}#{glob}" : glob
  rswag_to_oas!("modules/appeals_api/app/swagger/appeals_api/v2/swagger#{glob}.json")
end

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
    desc 'Generate single rswag docs and schemas for appeals_api'
    task run: %i[prod]

    task prod: :environment do
      generate_swagger_doc
    end

    task dev: :environment do
      generate_swagger_doc(dev: true)
    end

    APPEALS_API_SECTION_SLUGS.each do |section_slug|
      namespace section_slug do
        task run: %i[prod]

        task prod: :environment do
          generate_swagger_doc(section: section_slug)
        end

        task dev: :environment do
          generate_swagger_doc(dev: true, section: section_slug)
        end
      end
    end

    desc 'Generate rswag docs for all sections of the appeals_api'
    task all: :environment do
      Parallel.each(
        ['rswag:appeals_api:run'].concat(APPEALS_API_SECTION_SLUGS.map { |section| "rswag:appeals_api:#{section}:run" })
      ) { |task_name| Rake::Task[task_name].invoke }
    end

    desc 'Generate rswag docs for all sections of the appeals_api (dev)'
    task all_dev: :environment do
      Parallel.each(
        ['rswag:appeals_api:dev'].concat(APPEALS_API_SECTION_SLUGS.map { |section| "rswag:appeals_api:#{section}:dev" })
      ) { |task_name| Rake::Task[task_name].invoke }
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

# Does file manipulation to make an rswag-output json file compatible to OAS v3
# Rwag still generates `basePath`, which is invalid in OAS v3 (https://github.com/rswag/rswag/issues/318)
def rswag_to_oas!(filepath)
  temp_path = "/tmp/#{SecureRandom.urlsafe_base64}.json"
  File.open(temp_path, 'w') do |outfile|
    File.foreach(filepath) do |line|
      outfile.puts line unless line.include?('basePath')
    end
  end

  FileUtils.mv(temp_path, filepath)
end
