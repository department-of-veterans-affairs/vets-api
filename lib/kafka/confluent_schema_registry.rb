# frozen_string_literal: true

class Kafka::ConfluentSchemaRegistry
  def initialize(url)
    headers = {
      'Accept' => 'application/json',
      'User-Agent' => 'Vets.gov Agent',
      'Content-Type' => 'application/vnd.schemaregistry.v1+json'
    }

    @connection = Faraday.new(url, headers:)
  end

  def fetch(id)
    data = get("/schemas/ids/#{id}", idempotent: true)
    data.fetch('schema')
  end

  def register(subject, schema)
    data = post("/subjects/#{subject}/versions", body: { schema: schema.to_s }.to_json)

    data.fetch('id')
  end

  # List all subjects
  def subjects
    get('/subjects', idempotent: true)
  end

  # List all versions for a subject
  def subject_versions(subject)
    get("/subjects/#{subject}/versions", idempotent: true)
  end

  # Get a specific version for a subject
  def subject_version(subject, version = 'latest')
    get("/subjects/#{subject}/versions/#{version}", idempotent: true)
  end

  # Get the subject and version for a schema id
  def schema_subject_versions(schema_id)
    get("/schemas/ids/#{schema_id}/versions", idempotent: true)
  end

  # Check if a schema exists. Returns nil if not found.
  def check(subject, schema)
    data = post("/subjects/#{subject}",
                expects: [200, 404],
                body: { schema: schema.to_s }.to_json,
                idempotent: true)
    data unless data.key?('error_code')
  end

  # Check if a schema is compatible with the stored version.
  # Returns:
  # - true if compatible
  # - nil if the subject or version does not exist
  # - false if incompatible
  # http://docs.confluent.io/3.1.2/schema-registry/docs/api.html#compatibility
  def compatible?(subject, schema, version = 'latest')
    data = post("/compatibility/subjects/#{subject}/versions/#{version}",
                expects: [200, 404], body: { schema: schema.to_s }.to_json, idempotent: true)
    data.fetch('is_compatible', false) unless data.key?('error_code')
  end

  # Check for specific schema compatibility issues
  # Returns:
  # - nil if the subject or version does not exist
  # - a list of compatibility issues
  # https://docs.confluent.io/platform/current/schema-registry/develop/api.html#sr-api-compatibility
  def compatibility_issues(subject, schema, version = 'latest')
    data = post("/compatibility/subjects/#{subject}/versions/#{version}",
                expects: [200, 404], body: { schema: schema.to_s }.to_json, query: { verbose: true }, idempotent: true)

    data.fetch('messages', []) unless data.key?('error_code')
  end

  # Get global config
  def global_config
    get('/config', idempotent: true)
  end

  # Update global config
  def update_global_config(config)
    put('/config', body: config.to_json, idempotent: true)
  end

  # Get config for subject
  def subject_config(subject)
    get("/config/#{subject}", idempotent: true)
  end

  # Update config for subject
  def update_subject_config(subject, config)
    put("/config/#{subject}", body: config.to_json, idempotent: true)
  end

  private

  def get(path, **)
    request(path, method: :get, **)
  end

  def put(path, **)
    request(path, method: :put, **)
  end

  def post(path, **)
    request(path, method: :post, **)
  end

  def request(path, method: :get, **options)
    options = { expects: 200 }.merge!(options)
    response = @connection.send(method, path) do |req|
      req.headers = options[:headers] if options[:headers]
    end

    JSON.parse(response.body)
  end
end
