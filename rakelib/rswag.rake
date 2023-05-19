# frozen_string_literal: true

require 'fileutils'

APPEALS_API_DOCS_DIR = 'modules/appeals_api/spec/docs'

APPEALS_API_DOCS = [
  {
    name: 'appealable_issues',
    version: 'v0',
    pattern: "#{APPEALS_API_DOCS_DIR}/appealable_issues/v0_spec.rb"
  },
  {
    name: 'appeals_status',
    version: 'v1',
    pattern: "#{APPEALS_API_DOCS_DIR}/appeals_status/v1_spec.rb"
  },
  {
    name: 'decision_reviews',
    version: 'v2',
    pattern: "#{APPEALS_API_DOCS_DIR}/decision_reviews"
  },
  {
    name: 'higher_level_reviews',
    version: 'v0',
    pattern: "#{APPEALS_API_DOCS_DIR}/higher_level_reviews/v0_spec.rb"
  },
  {
    name: 'legacy_appeals',
    version: 'v0',
    pattern: "#{APPEALS_API_DOCS_DIR}/legacy_appeals/v0_spec.rb"
  },
  {
    name: 'notice_of_disagreements',
    version: 'v0',
    pattern: "#{APPEALS_API_DOCS_DIR}/notice_of_disagreements/v0_spec.rb"
  },
  {
    name: 'supplemental_claims',
    version: 'v0',
    pattern: "#{APPEALS_API_DOCS_DIR}/supplemental_claims/v0_spec.rb"
  }
].freeze

APPEALS_API_NAMES = APPEALS_API_DOCS.pluck(:name).freeze

def run_tasks_in_parallel(task_names)
  Parallel.each(task_names) { |task_name| Rake::Task[task_name].invoke }
end

def abbreviate_snake_case_name(name)
  name.scan(/(?<=^|_)(\S)/).join
end

def appeals_api_output_files(dev: false)
  APPEALS_API_DOCS.map do |config|
    "modules/appeals_api/app/swagger/#{config[:name]}/#{config[:version]}/swagger#{dev ? '_dev' : ''}.json"
  end
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

    desc 'Generate rswag docs by environment for the claims_api'
    task build: :environment do
      ENV['PATTERN'] = 'modules/claims_api/spec/requests/**/*_spec.rb'
      ENV['RAILS_MODULE'] = 'claims_api'
      ENV['SWAGGER_DRY_RUN'] = '0'
      %w[dev production].each do |environment|
        ENV['DOCUMENTATION_ENVIRONMENT'] = environment
        Rake::Task['rswag:specs:swaggerize'].invoke
        %w[v1 v2].each { |version| strip_swagger_base_path(version, (version.eql?('v2') ? environment : nil)) }
        Rake::Task['rswag:specs:swaggerize'].reenable
      end
    end
  end

  namespace :appeals_api do
    APPEALS_API_DOCS.each do |config|
      namespace abbreviate_snake_case_name(config[:name]).to_sym do
        desc "Generate all docs for the #{config[:name]} appeals API"
        task all: :environment do
          run_tasks_in_parallel(%w[dev prod].map do |env|
            "rswag:appeals_api:#{abbreviate_snake_case_name(config[:name])}:#{env}"
          end)
        end

        desc "Generate production docs for the #{config[:name]} appeals API"
        task prod: :environment do
          generate_appeals_doc(config[:name], config[:version])
        end

        desc "Generate development docs for the #{config[:name]} appeals API"
        task dev: :environment do
          generate_appeals_doc(config[:name], config[:version], dev: true)
        end
      end
    end

    desc 'Generate rswag docs for all appeals APIs'
    task all: :environment do
      run_tasks_in_parallel(APPEALS_API_NAMES.map do |api_name|
        "rswag:appeals_api:#{abbreviate_snake_case_name(api_name)}:all"
      end)
    end
  end
end

def strip_swagger_base_path(version, env = nil)
  # Rwag still generates `basePath`, which is invalid in OAS v3 (https://github.com/rswag/rswag/issues/318)
  # This removes the basePath value from the generated JSON file(s)
  path = "app/swagger/claims_api/#{version}/swagger.json"
  path = "app/swagger/claims_api/#{version}/#{env}/swagger.json" if version.eql?('v2')
  swagger_file_path = ClaimsApi::Engine.root.join(path)
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

def generate_appeals_doc(api_name, api_version, dev: false)
  ENV['RAILS_MODULE'] = 'appeals_api'
  ENV['SWAGGER_DRY_RUN'] = '0'
  ENV['PATTERN'] = 'modules/appeals_api/spec/docs'
  # FIXME: these two environment variables can be removed, but schema generation needs to be refactored first
  ENV['API_NAME'] = api_name
  ENV['API_VERSION'] = api_version

  if dev
    ENV['RSWAG_ENV'] = 'dev'
    ENV['WIP_DOCS_ENABLED'] = Settings.modules_appeals_api.documentation.wip_docs&.join(',') || ''
  end

  begin
    Rake::Task['rswag:specs:swaggerize'].invoke
  rescue => e
    warn "Rswag doc generation for #{api_name} #{api_version} #{dev ? '(dev) ' : ''}failed:"
    puts e.full_message(highlight: true, order: :top)
    exit 1
  end

  # Correct formatting on rswag output so that it matches the expected OAS format
  appeals_api_output_files(dev:).each { |file_path| rswag_to_oas!(file_path) }
end
