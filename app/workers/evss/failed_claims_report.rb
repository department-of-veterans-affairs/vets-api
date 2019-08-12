# frozen_string_literal: true

module EVSS
  class FailedClaimsReport
    include Sidekiq::Worker

    S3_CLAIMS_RESOURCE_OPTIONS = {
      access_key_id: Settings.evss.s3.aws_access_key_id,
      secret_access_key: Settings.evss.s3.aws_secret_access_key,
      region: Settings.evss.s3.region
    }.freeze

    def get_document_hash(evss_metadata)
      @dead_set ||= Sidekiq::DeadSet.new
      document_hash = nil

      @dead_set.each do |job|
        args = job.args
        this_document_hash = args[2]

        if args[1] == evss_metadata[:user_uuid] &&
           this_document_hash['file_name'] == evss_metadata[:file_name] &&
           (
             evss_metadata[:tracked_item_id].nil? ||
             evss_metadata[:tracked_item_id] == this_document_hash['tracked_item_id']
           )

          document_hash = this_document_hash
          break
        end
      end

      document_hash
    end

    def get_evss_metadata(file_path)
      file_path_split = file_path.split('/')
      has_tracked_item_id = file_path_split.size == 4 && file_path_split[2] != 'null'

      {
        user_uuid: file_path_split[1],
        tracked_item_id: has_tracked_item_id ? file_path_split[2].to_i : nil,
        file_name: file_path_split.last
      }
    end

    def perform
      s3 = Aws::S3::Resource.new(S3_CLAIMS_RESOURCE_OPTIONS)
      failed_uploads = []
      sidekiq_retry_timeout = 21.days.ago

      %w[evss disability].each do |type|
        s3.bucket(Settings.evss.s3.bucket).objects(prefix: "#{type}_claim_documents").each do |object|
          if object.last_modified < sidekiq_retry_timeout
            failed_uploads << {
              file_path: object.key,
              last_modified: object.last_modified
            }
          end
        end
      end

      failed_uploads.each do |failed_upload|
        failed_upload[:document_hash] = get_document_hash(get_evss_metadata(failed_upload[:file_path]))
      end

      FailedClaimsReportMailer.build(failed_uploads).deliver_now
    end
  end
end
