# frozen_string_literal: true

require 'base64'
require 'fileutils'
require 'securerandom'

module Idp
  # Drop-in replacement for Idp::Client used in development and test.
  # Lives outside app/services so it never loads in production.
  class MockClient
    def initialize
      @storage_dir = Rails.root.join('tmp', 'idp')
      FileUtils.mkdir_p(@storage_dir)
    end

    def intake(file_name:, pdf_base64:)
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

      persist_document(payload)

      payload.slice('id', 'bucket', 'pdf_key')
    end

    def status(id)
      data = load_document(id)
      {
        'id' => id,
        'scan_status' => data['scan_status'],
        'received_at' => data['created_at'],
        'file_name' => data['file_name']
      }
    end

    # rubocop:disable Lint/UnusedMethodArgument
    def output(id, type:)
      data = load_document(id)
      { 'forms' => data['forms'] }
    end
    # rubocop:enable Lint/UnusedMethodArgument

    def download(id, kvpid:)
      data = load_document(id)
      artifact = data['artifacts'][kvpid]
      raise Idp::Error, "Artifact #{kvpid} not found" if artifact.blank?

      artifact
    end

    private

    attr_reader :storage_dir

    def document_path(id)
      storage_dir.join("#{id}.json")
    end

    def persist_document(payload)
      File.write(document_path(payload['id']), JSON.pretty_generate(payload))
    end

    def load_document(id)
      JSON.parse(File.read(document_path(id)))
    rescue Errno::ENOENT
      raise Idp::Error, "Document #{id} not found"
    end

    def sample_forms(id)
      [
        { 'artifactType' => 'DD214',  'mmsArtifactValidationId' => "#{id}-dd214" },
        { 'artifactType' => 'DEATH',  'mmsArtifactValidationId' => "#{id}-death" }
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
