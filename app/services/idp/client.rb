# frozen_string_literal: true

require 'base64'
require 'fileutils'
require 'securerandom'

module Idp
  class Client
    class Error < StandardError; end

    DEFAULT_TIMEOUT = 15

    def initialize(base_url: nil, timeout: nil, mock: nil)
      @mock_mode = mock.nil? ? Settings.try(:idp)&.try(:mock) : mock
      @mock_mode = !!@mock_mode

      if mock_mode
        @storage_dir = Rails.root.join('tmp', 'idp_documents')
        FileUtils.mkdir_p(@storage_dir)
      else
        @base_url = base_url.presence || Settings.try(:idp)&.try(:base_url) || ENV['IDP_API_BASE_URL']
        @timeout = timeout || Settings.try(:idp)&.try(:timeout) || ENV['IDP_API_TIMEOUT']&.to_i || DEFAULT_TIMEOUT
        raise Error, 'IDP base URL is not configured' if @base_url.blank?
      end
    end

    def intake(file_name:, pdf_base64:)
      return mock_intake(file_name:, pdf_base64:) if mock_mode

      post('intake', { pdf_b64: pdf_base64 }, 'X-Filename' => file_name)
    end

    def status(id)
      return mock_status(id) if mock_mode

      get('status', { id: })
    end

    def output(id, type:)
      return mock_output(id, type) if mock_mode

      get('output', { id:, type: })
    end

    def download(id, kvpid:)
      return mock_download(id, kvpid) if mock_mode

      get('download', { id:, kvpid: })
    end

    private

    attr_reader :base_url, :timeout, :mock_mode, :storage_dir

    def connection
      @connection ||= Faraday.new(url: normalized_base_url) do |conn|
        conn.request :json
        conn.response :json, content_type: /\bjson$/
        conn.response :raise_error
        conn.options.timeout = timeout
        conn.options.open_timeout = timeout
        conn.adapter Faraday.default_adapter
      end
    end

    def normalized_base_url
      base_url.end_with?('/') ? base_url : "#{base_url}/"
    end

    def get(path, params = {})
      perform_request { connection.get(path, params) }
    end

    def post(path, body, headers = {})
      perform_request do
        connection.post(path) do |req|
          req.headers['Content-Type'] = 'application/json'
          headers.each do |key, value|
            req.headers[key] = value if value.present?
          end
          req.body = body
        end
      end
    end

    def perform_request
      response = yield
      response.body
    rescue Faraday::Error => e
      raise Error, e.message
    end

    # --------------------
    # Mock helpers
    # --------------------

    def mock_intake(file_name:, pdf_base64:)
      id = SecureRandom.uuid
      created_at = Time.zone.now.iso8601
      decoded = Base64.decode64(pdf_base64)

      File.binwrite(storage_dir.join("#{id}.pdf"), decoded)

      payload = {
        'id' => id,
        'bucket' => 'local-idp',
        'pdf_key' => "#{id}/pdf/#{file_name}",
        'file_name' => file_name,
        'scan_status' => 'completed',
        'created_at' => created_at,
        'forms' => sample_forms(id),
        'artifacts' => sample_artifacts(id)
      }

      persist_mock_document(payload)

      payload.slice('id', 'bucket', 'pdf_key')
    end

    def mock_status(id)
      data = load_mock_document(id)
      {
        'id' => id,
        'scan_status' => data['scan_status'],
        'received_at' => data['created_at'],
        'file_name' => data['file_name']
      }
    end

    def mock_output(id, type)
      data = load_mock_document(id)
      case (type || 'artifact')
      when 'artifact'
        { 'forms' => data['forms'] }
      else
        { 'forms' => data['forms'] }
      end
    end

    def mock_download(id, kvpid)
      data = load_mock_document(id)
      artifact = data['artifacts'][kvpid]
      raise Error, "Artifact #{kvpid} not found" if artifact.blank?

      artifact
    end

    def mock_document_path(id)
      storage_dir.join("#{id}.json")
    end

    def persist_mock_document(payload)
      File.write(mock_document_path(payload['id']), JSON.pretty_generate(payload))
    end

    def load_mock_document(id)
      JSON.parse(File.read(mock_document_path(id)))
    rescue Errno::ENOENT
      raise Error, "Document #{id} not found"
    end

    def sample_forms(id)
      [
        {
          'artifactType' => 'DD214',
          'mmsArtifactValidationId' => "#{id}-dd214"
        },
        {
          'artifactType' => 'DEATH',
          'mmsArtifactValidationId' => "#{id}-death"
        }
      ]
    end

    def sample_artifacts(id)
      {
        "#{id}-dd214" => sample_dd214_artifact,
        "#{id}-death" => sample_death_artifact
      }
    end

    def sample_dd214_artifact
      {
        'FIRST_NAME' => 'Alex',
        'MIDDLE_NAME' => 'J',
        'LAST_NAME' => 'Tester',
        'SUFFIX' => '',
        'SOCIAL_SECURITY_NUMBER' => '123456789',
        'DATE_OF_BIRTH' => '01-15-1960',
        'BRANCH_OF_SERVICE' => 'Army',
        'GRADE_RATE_RANK' => 'Sergeant',
        'PAY_GRADE' => 'E5',
        'DATE_INDUCTED' => '03-01-1978',
        'DATE_ENTERED_ACTIVE_SERVICE' => '03-01-1978',
        'DATE_SEPARATED_ACTIVE_SERVICE' => '04-01-1982',
        'CAUSE_OF_SEPARATION' => 'Expiration of Term',
        'SEPARATION_TYPE' => 'Honorable',
        'SEPARATION_CODE' => 'JLK'
      }
    end

    def sample_death_artifact
      {
        'FIRST_NAME' => 'Jamie',
        'MIDDLE_NAME' => 'K',
        'LAST_NAME' => 'Tester',
        'SUFFIX' => '',
        'SOCIAL_SECURITY_NUMBER' => '987654321',
        'MARITAL_STATUS_AT_TIME_OF_DEATH' => 'Married',
        'DISPOSITION_DATE' => '06-10-2024',
        'DATE_OF_DEATH' => '06-05-2024',
        'CAUSE_OF_DEATH_A' => 'Cardiac arrest',
        'CAUSE_OF_DEATH_B' => 'Hypertension',
        'CAUSE_OF_DEATH_C' => '',
        'CAUSE_OF_DEATH_D' => '',
        'CAUSE_OF_DEATH_OTHER' => '',
        'MANNER_OF_DEATH' => 'Natural'
      }
    end
  end
end
