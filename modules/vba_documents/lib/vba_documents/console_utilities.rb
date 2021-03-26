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

    private

    def manual_status_change(guid, from, to, error)
      r = UploadSubmission.find_by guid: guid
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
  end
end

# require './modules/vba_documents/lib/vba_documents/console_utilities.rb'
# include VBADocuments
# include ConsoleUtilities
# error_hash = {'code'=>'DOC102', 'detail'=>'duplicates...'}
# from = 'success'
# to = 'vbms'
# invalid_guids = process_manual_status_changes(guids,from,to,error_hash)
