# frozen_string_literal: true

module Vye
  module BatchTransfer
    module IngressFiles
      BDN_FEED_FILENAME = 'wave.txt'
      TIMS_FEED_FILENAME = 'tims32towave.txt'

      private_constant :BDN_FEED_FILENAME, :TIMS_FEED_FILENAME

      extend self

      private

      def bdn_feed_filename = BDN_FEED_FILENAME

      def tims_feed_filename = TIMS_FEED_FILENAME

      def credentials = Vye.settings.s3.to_h.slice(:region, :access_key_id, :secret_access_key)

      def bucket = Vye.settings.s3.bucket

      def external_bucket = Vye.settings.s3.external_bucket

      def s3_client = Aws::S3::Client.new(**credentials)

      def download(filename)
        date = Time.zone.today.strftime('%Y-%m-%d')
        response_target = Rails.root / "tmp/vye/downloads/#{date}/#{filename}"
        key = "scanned/#{filename}"

        response_target.dirname.mkpath
        s3_client.get_object(response_target:, bucket:, key:)

        yield response_target
      ensure
        response_target.delete
      end

      def bdn_import(path)
        bdn_clone = BdnClone.create!
        source = :bdn_feed
        path.each_line.with_index do |line, index|
          locator = index + 1
          line.chomp!
          records = BdnLineExtraction.new(line:).attributes
          Vye::LoadData.new(source:, locator:, bdn_clone:, records:)
        end
      end

      def tims_import(path)
        data = CSV.open(path, 'r', headers: %i[ssn file_number doc_type queue_date rpo])
        source = :tims_feed
        data.each.with_index do |row, index|
          locator = index + 1
          records = TimsLineExtraction.new(row:).records
          Vye::LoadData.new(source:, locator:, records:)
        end
      end

      public

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

      def clear_fixtures
        EgressFiles.clear_from(bucket: :internal, path: 'scanned')
      end

      def bdn_load = download(bdn_feed_filename, &method(:bdn_import))

      def tims_load = download(tims_feed_filename, &method(:tims_import))
    end
  end
end
