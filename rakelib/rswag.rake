# frozen_string_literal: true

require 'fileutils'

APPEALS_API_DOCS_DIR = 'modules/appeals_api/spec/docs'

APPEALS_API_DOCS = [
  { name: 'appealable_issues', version: 'v0' },
  { name: 'appeals_status', version: 'v1' },
  { name: 'decision_reviews', version: 'v2' },
  { name: 'higher_level_reviews', version: 'v0' },
  { name: 'legacy_appeals', version: 'v0' },
  { name: 'notice_of_disagreements', version: 'v0' },
  { name: 'supplemental_claims', version: 'v0' }
].freeze

APPEALS_API_NAMES = APPEALS_API_DOCS.pluck(:name).freeze

def appeals_api_output_files(dev: false)
  suffix = dev ? '_dev' : ''
  APPEALS_API_DOCS.map do |config|
    "modules/appeals_api/app/swagger/#{config[:name]}/#{config[:version]}/swagger#{suffix}.json"
  end
end

def run_tasks_in_parallel(task_names)
  Parallel.each(task_names) { |task_name| Rake::Task[task_name].invoke }
end

def abbreviate_snake_case_name(name)
  name.scan(/(?<=^|_)(\S)/).join
end

namespace :rswag do
  namespace :openapi do
    desc 'Generate rswag docs for all VA.gov APIs'
    task build: :environment do
      ENV['PATTERN'] = 'spec/rswag/v0/*_spec.rb'
      ENV['RAILS_MODULE'] = 'public'
      ENV['SWAGGER_DRY_RUN'] = '0'
      Rake::Task['rswag:specs:swaggerize'].invoke
    end
  end

  namespace :claims_api do
    desc 'Generate rswag docs by environment for the claims_api'
    task build: :environment do
      ENV['PATTERN'] = 'modules/claims_api/spec/requests/**/*_spec.rb'
      ENV['RAILS_MODULE'] = 'claims_api'
      ENV['SWAGGER_DRY_RUN'] = '0'
      %w[dev production].each do |environment|
        ENV['DOCUMENTATION_ENVIRONMENT'] = environment
        Rake::Task['rswag:specs:swaggerize'].invoke
        %w[v1 v2].each { |version| format_for_swagger(version, version.eql?('v2') ? environment : nil) }
        Rake::Task['rswag:specs:swaggerize'].reenable
      end
      # Sanitize dynamic values after generation to reduce noise in git diffs
      sanitize_claims_api_docs!
    end
  end

  namespace :appeals_api do
    desc 'Generate production docs for all appeals APIs'
    task prod: :environment do
      generate_appeals_docs
    end

    desc 'Generate development docs for all appeals APIs'
    task dev: :environment do
      generate_appeals_docs(dev: true)
    end

    desc 'Generate all docs for all appeals APIs'
    task all: :environment do
      run_tasks_in_parallel(%w[rswag:appeals_api:prod rswag:appeals_api:dev])
    end
  end

  namespace :representation_management do
    desc 'Generate rswag docs for representation_management'
    task build: :environment do
      ENV['PATTERN'] = 'modules/representation_management/spec/requests/**/*_spec.rb'
      ENV['RAILS_MODULE'] = 'representation_management'
      ENV['SWAGGER_DRY_RUN'] = '0'
      Rake::Task['rswag:specs:swaggerize'].invoke
    end
  end
end

def generate_appeals_docs(dev: false)
  ENV['RAILS_MODULE'] = 'appeals_api'
  ENV['SWAGGER_DRY_RUN'] = '0'
  ENV['PATTERN'] = APPEALS_API_DOCS_DIR

  if dev
    ENV['RSWAG_ENV'] = 'dev'
    ENV['WIP_DOCS_ENABLED'] = Settings.modules_appeals_api.documentation.wip_docs&.join(',') || ''
  end

  begin
    Rake::Task['rswag:specs:swaggerize'].invoke
  rescue => e
    warn 'Rswag doc generation failed:'
    puts e.full_message(highlight: true, order: :top)
    exit 1
  end

  # Correct formatting on rswag output so that it matches the expected OAS format
  appeals_api_output_files(dev:).each { |file_path| rswag_to_oas!(file_path) }
end

# validates the null values for fields in the JSON correctly we use type: ['string', 'null']
# Swagger displays that as stringnull so in order to make the docs remain readable we remove the null before writing
def format_for_swagger(version, env = nil)
  path = "app/swagger/claims_api/#{version}/swagger.json"
  path = "app/swagger/claims_api/#{version}/#{env}/swagger.json" if version.eql?('v2')
  swagger_file_path = ClaimsApi::Engine.root.join(path)
  oas = JSON.parse(File.read(swagger_file_path.to_s))

  clear_null_types!(oas) if version == 'v2'
  clear_null_enums!(oas) if version == 'v2'
  File.write(swagger_file_path, JSON.pretty_generate(oas))
end

def deep_transform(hash, transformer:, root: [])
  return unless hash.is_a?(Hash)

  ret = hash.map do |key, v|
    v = transformer.call key, v, root
    h_ret = v
    proot = root.dup
    if v.is_a? Hash
      root.push(key)
      h_ret = deep_transform(v, root: root.dup, transformer:)
      root = proot
    elsif v.is_a? Array
      root.push(key)
      h_ret = v.map do |val|
        next deep_transform(val, root: root.dup, transformer:) if val.is_a?(Hash) || val.is_a?(Array)

        next val
      end
      root = proot
    end
    [key, h_ret]
  end
  ret.to_h
end

def clear_null_types!(data)
  transformer = lambda do |k, v, root|
    if k == 'type' && v.is_a?(Array) && root[0] == 'paths'
      r = v.excluding('null')
      r.size > 1 ? r : r[0]
    else
      v
    end
  end
  data.replace deep_transform(data, transformer:)
end

def clear_null_enums!(data)
  transformer = lambda do |k, v, root|
    if k == 'enum' && v.is_a?(Array) && root.include?('schema')
      v.compact
    else
      v
    end
  end
  data.replace deep_transform(data, transformer:)
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

# Sanitize dynamic values in examples to prevent noisy git diffs
def sanitize_claims_api_docs!
  paths = [
    'modules/claims_api/app/swagger/claims_api/v1/swagger.json',
    'modules/claims_api/app/swagger/claims_api/v2/dev/swagger.json',
    'modules/claims_api/app/swagger/claims_api/v2/production/swagger.json'
  ]

  paths.each do |path|
    filepath = Rails.root.join(path)
    next unless File.exist?(filepath)

    data = JSON.parse(File.read(filepath))
    sanitize_example_values!(data)
    File.write(filepath, JSON.pretty_generate(data))
  end
end

# Sanitize dynamic values in swagger examples
def sanitize_example_values!(data)
  UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  
  # Counter to generate sequential stable UUIDs
  @uuid_counter ||= 0

  transformer = lambda do |_k, v, _root|
    # Sanitize UUID-style IDs
    if v.is_a?(String) && v.match?(UUID_REGEX)
      @uuid_counter += 1
      format('00000000-0000-0000-0000-%012d', @uuid_counter)
    else
      v
    end
  end

  data.replace deep_transform(data, root: [], transformer:)
end
