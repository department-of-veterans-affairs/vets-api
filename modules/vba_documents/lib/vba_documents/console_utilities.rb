# frozen_string_literal: true

module VBADocuments
  module ConsoleUtilities
    INVALID_PARAMETERS = 'invalid from/to parameter(s) passed'
    ERROR_STATUS_VALIDATION = 'Please provide ONLY the code and detail for status ERROR'

    def process_manual_status_changes(guids, from, to, error = {})
      # validate parameters passed
      raise INVALID_PARAMETERS if ([from, to] & UploadSubmission::ALL_STATUSES) != [from, to]
      raise ERROR_STATUS_VALIDATION if to.eql?('error') && error.keys != %w[code detail]

      invalid_guids = []
      guids.each do |g|
        invalid_guid = manual_status_change(g, from, to, error)
        invalid_guids << g if invalid_guid
      end
      invalid_guids
    end

    def pull_download(guid)
      doc_exists = UploadSubmission.where('guid = ? and s3_deleted is null', guid).count.positive?
      raise 'Temp file no longer exists on AWS' unless doc_exists

      tempfile = VBADocuments::PayloadManager.download_raw_file(guid).first
      upload_model = UploadFile.new
      upload_model.multipart.attach(io: tempfile, filename: upload_model.guid)
      upload_model.status = 'forensics'
      upload_model.save!
      upload_model.parse_and_upload!
      upload_model
    end

    def cleanup(upload_file)
      raise 'Invalid upload file parameter passed.' unless upload_file.is_a? UploadFile

      upload_file.remove_from_storage
      upload_file.parsed_files.purge
      upload_file.delete
    end

    def mark_success_as_final(guids)
      invalid_guids = []
      guids.each do |g|
        invalid_guid = mark_success_final(g)
        invalid_guids << g if invalid_guid
      end
      invalid_guids
    end

    private

    def manual_status_change(guid, from, to, error)
      r = UploadSubmission.find_by(guid:)
      if r&.status.eql?(from)
        UploadSubmission.transaction do
          # record the promotion
          promotion = {}
          promotion['promoted_at'] = Time.now.to_i
          promotion['from_status'] = from
          promotion['to_status'] = to
          r.metadata['manual_status_change'] = promotion

          if to.eql? 'error'
            r.code = error['code']
            r.detail = error['detail']
          end
          r.status = to
          r.save!
        end
      end
      r.nil?
    end

    # this method marks records in success status that will no longer be checked for manual promotion to vbms
    def mark_success_final(guid)
      r = UploadSubmission.find_by(guid:)
      if r&.status.eql?('success')
        UploadSubmission.transaction do
          unless r.metadata[UploadSubmission::FINAL_SUCCESS_STATUS_KEY]
            # record this as the final status to the current time
            r.metadata[UploadSubmission::FINAL_SUCCESS_STATUS_KEY] = Time.now.to_i
            r.save!(touch: false)
          end
        end
      end
      r.nil?
    end
  end
end

# require './modules/vba_documents/lib/vba_documents/console_utilities.rb'
# include VBADocuments
# include ConsoleUtilities
# error_hash = {'code'=>'DOC102', 'detail'=>'duplicates...'}
# from = 'success'
# to = 'vbms'
# invalid_guids = process_manual_status_changes(guids,from,to,error_hash)
#
#
# CLEANUP ALL FORENSICS
# f = UploadFile.where(status: 'forensics')
# f.each do |uf| cleanup(uf) end
