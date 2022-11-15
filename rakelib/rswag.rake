# frozen_string_literal: true

require 'fileutils'

APPEALS_API_DOCS_DIR = 'modules/appeals_api/spec/docs'
APPEALS_API_NAMES = Dir["#{APPEALS_API_DOCS_DIR}/*.rb"]
                    .map { |file_name| File.basename(file_name, '_spec.rb') }

def run_tasks_in_parallel(task_names)
  Parallel.each(task_names) { |task_name| Rake::Task[task_name].invoke }
end

def abbreviate_snake_case_name(name)
  name.scan(/(?<=^|_)(\S)/).join
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
    desc 'Generate docs for appeals_api decision reviews'
    task run: %i[prod]

    task prod: :environment do
      generate_appeals_doc
    end

    desc 'Generate docs for appeals_api decision reviews (dev)'
    task dev: :environment do
      generate_appeals_doc(dev: true)
    end

    APPEALS_API_NAMES.each do |api_name|
      namespace abbreviate_snake_case_name(api_name) do
        desc "Generate docs for appeals_api #{api_name}"
        task run: %i[prod]

        task prod: :environment do
          generate_appeals_doc(api_name)
        end

        desc "Generate docs for appeals_api #{api_name} (dev)"
        task dev: :environment do
          generate_appeals_doc(api_name, dev: true)
        end
      end
    end

    desc 'Generate rswag docs for all sections of the appeals_api'
    task all: :environment do
      run_tasks_in_parallel(['rswag:appeals_api:run'] +
        APPEALS_API_NAMES.map { |api_name| "rswag:appeals_api:#{abbreviate_snake_case_name(api_name)}:run" })
    end

    desc 'Generate rswag docs for all sections of the appeals_api (dev)'
    task all_dev: :environment do
      run_tasks_in_parallel(['rswag:appeals_api:dev'] +
        APPEALS_API_NAMES.map { |api_name| "rswag:appeals_api:#{abbreviate_snake_case_name(api_name)}:dev" })
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

def generate_appeals_doc(api_name = nil, dev: false)
  ENV['RAILS_MODULE'] = 'appeals_api'
  ENV['SWAGGER_DRY_RUN'] = '0'
  if dev
    ENV['RSWAG_ENV'] = 'dev'
    ENV['WIP_DOCS_ENABLED'] = Settings.modules_appeals_api.documentation.wip_docs&.join(',') || ''
  end
  ENV['API_NAME'] = api_name if api_name
  ENV['PATTERN'] = api_name ? "#{APPEALS_API_DOCS_DIR}/#{api_name}_spec.rb" : APPEALS_API_DOCS_DIR
  Rake::Task['rswag:specs:swaggerize'].invoke

  # Correct formatting on rswag output so that it matches the expected OAS format
  suffix = dev ? '_dev' : ''
  rswag_to_oas!(
    if api_name.nil?
      "modules/appeals_api/app/swagger/appeals_api/v2/swagger#{suffix}.json"
    else
      "modules/appeals_api/app/swagger/#{api_name}/v0/swagger#{suffix}.json"
    end
  )
end
