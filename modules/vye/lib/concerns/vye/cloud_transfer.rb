# frozen_string_literal: true

module Vye
  module CloudTransfer
    module_function

    def credentials
      Vye.settings.s3.to_h.slice(:region, :access_key_id, :secret_access_key)
    end

    def bucket
      Vye.settings.s3.bucket
    end

    def external_bucket
      Vye.settings.s3.external_bucket
    end

    def s3_client
      Aws::S3::Client.new(**credentials)
    end

    def tmp_dir
      result = Rails.root / "tmp/vye/#{SecureRandom.uuid}"
      result.mkpath
      result
    end

    def tmp_path(filename) = tmp_dir / filename

    def download(filename)
      response_target = tmp_path filename
      key = "scanned/#{filename}"

      s3_client.get_object(response_target:, bucket:, key:)

      yield response_target
    ensure
      response_target.delete
    end

    def upload(file, prefix: 'processed')
      key = "#{prefix}/#{file.basename}"
      body = file.open('rb')
      content_type = 'text/plain'

      s3_client.put_object(bucket:, key:, body:, content_type:)
    ensure
      body.close
    end

    def upload_report(filename, &)
      path = tmp_path filename
      path.open('w', &)
      upload(path)
    ensure
      path.delete
    end

    def clear_from(bucket_sym: :internal, path: 'processed')
      bucket = { internal: self.bucket, external: external_bucket }[bucket_sym]
      prefix = "#{path}/"
      check_s3_location!(bucket:, path:)

      s3_client
        .list_objects_v2(bucket:, prefix:)
        .contents
        .map { |obj| obj.key unless obj.key.ends_with?('/') }
        .compact
        .each { |key| s3_client.delete_object(bucket:, key:) }
    end

    def check_s3_location!(bucket:, path:)
      case bucket
      when external_bucket
        raise ArgumentError, 'invalid external path' unless %w[inbound outbound].include?(path)
      when self.bucket
        raise ArgumentError, 'invalid internal path' unless %w[scanned processed].include?(path)
      else
        raise ArgumentError, 'bucket must be either the internal one or the external one'
      end
    end

    def upload_fixtures
      [
        Vye::Engine.root / "spec/fixtures/bdn_sample/#{bdn_feed_filename}",
        Vye::Engine.root / "spec/fixtures/tims_sample/#{tims_feed_filename}"
      ].each do |file|
        key = "scanned/#{file.basename}"
        body = file.read

        s3_client.put_object(bucket:, key:, body:)
      end
    end
  end
end
