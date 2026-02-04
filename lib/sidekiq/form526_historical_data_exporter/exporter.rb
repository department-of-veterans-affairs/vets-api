# frozen_string_literal: true

require 'common/s3_helpers'

module Sidekiq
  module Form526HistoricalDataExporter
    class Exporter
      def initialize(batch_size, start_id, end_id, data = [])
        @batch_size = batch_size.to_i
        @start_id = start_id
        @end_id = end_id
        @data = data
        @file_name = "#{start_id}_#{end_id}.json"
        @file_path_and_name = "tmp/#{@file_name}"
      end

      def write_to_file(content)
        File.write(@file_path_and_name, content)
      end

      def upload_to_s3!
        s3_resource = new_s3_resource

        Common::S3Helpers.upload_file(
          s3_resource:,
          bucket: s3_bucket,
          key: @file_name,
          file_path: @file_path_and_name,
          content_type: 'application/json'
        )
      end

      def s3_bucket
        Settings.form526_export.aws.bucket
      end

      def new_s3_resource
        Aws::S3::Resource.new(
          region: Settings.form526_export.aws.region,
          access_key_id: Settings.form526_export.aws.access_key_id,
          secret_access_key: Settings.form526_export.aws.secret_access_key
        )
      end

      def get_submission_stats(submission)
        [submission.id, submission.submitted_claim_id, submission.created_at, submission.form]
      end

      def process!
        all = []
        batches = Form526Submission.select(:id, :created_at, :encrypted_kms_key, :form_json_ciphertext,
                                           :submitted_claim_id).find_in_batches(batch_size: @batch_size,
                                                                                start: @start_id, finish: @end_id)
        batches.each do |batch|
          batch.each do |submission|
            all << get_submission_stats(submission)
          end
        end
        write_to_file(all.to_json)
        upload_to_s3!
      ensure
        Common::FileHelpers.delete_file_if_exists(@file_path_and_name)
      end
    end
  end
end
