# frozen_string_literal: true

# rake vye:data:manual_deletions
# this task deletes the daily direct deposit and address additions,
# and nullifies related verifications
namespace :vye do
  desc 'Delete files from scanned and chunked buckets in S3'
  task delete_processed_s3_files: :environment do |_cmd, _args|
    Vye::CloudTransfer.remove_aws_files_from_s3_buckets
  end
end
