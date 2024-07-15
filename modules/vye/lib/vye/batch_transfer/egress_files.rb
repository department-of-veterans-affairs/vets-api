# frozen_string_literal: true

module Vye
  module BatchTransfer
    module EgressFiles
      BDN_TIMEZONE = 'Central Time (US & Canada)'

      extend self

      private

      def credentials = Vye.settings.s3.to_h.slice(:region, :access_key_id, :secret_access_key)

      def bucket = Vye.settings.s3.bucket

      def external_bucket = Vye.settings.s3.external_bucket

      def s3_client = Aws::S3::Client.new(**credentials)

      def upload(file)
        key = "processed/#{file.basename}"
        body = file.open('rb')
        content_type = 'text/plain'

        s3_client.put_object(bucket:, key:, body:, content_type:)
      ensure
        body.close
        file.delete
      end

      def now_in_bdn_timezone
        Time.current.in_time_zone(BDN_TIMEZONE)
      end

      def prefixed_dated(prefix)
        "#{prefix}#{now_in_bdn_timezone.strftime('%Y%m%d%H%M%S')}.txt"
      end

      # Change of addresses send to Newman everyday.
      def address_changes_filename
        prefixed_dated 'CHGADD'
      end

      # Change of direct deposit send to Newman everyday.
      def direct_deposit_filename
        prefixed_dated 'DirDep'
      end

      # enrollment verification sent to BDN everyday.
      def verification_filename
        "vawave#{now_in_bdn_timezone.yday}"
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

      public

      def clear_from(bucket: :internal, path: 'processed')
        bucket = { internal: self.bucket, external: external_bucket }[bucket]
        prefix = "#{path}/"
        check_s3_location!(bucket:, path:)

        s3_client
          .list_objects_v2(bucket:, prefix:)
          .contents
          .map { |obj| obj.key unless obj.key.ends_with?('/') }
          .compact
          .each { |key| s3_client.delete_object(bucket:, key:) }
      end

      def address_changes_upload
        date = Time.zone.today.strftime('%Y-%m-%d')
        path = Rails.root / "tmp/vye/uploads/#{date}/#{address_changes_filename}"
        path.dirname.mkpath

        path.open('w') { |io| AddressChange.write_report(io) }

        upload(path)
      end

      def direct_deposit_upload
        date = Time.zone.today.strftime('%Y-%m-%d')
        path = Rails.root / "tmp/vye/uploads/#{date}/#{direct_deposit_filename}"
        path.dirname.mkpath

        path.open('w') { |io| DirectDepositChange.write_report(io) }

        upload(path)
      end

      def verification_upload
        date = Time.zone.today.strftime('%Y-%m-%d')
        path = Rails.root / "tmp/vye/uploads/#{date}/#{verification_filename}"
        path.dirname.mkpath

        path.open('w') { |io| Verification.write_report(io) }

        upload(path)
      end
    end
  end
end
