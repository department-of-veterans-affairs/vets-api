# frozen_string_literal: true

module ClaimsApi
  class DocumentServiceBase < ServiceBase
    def compact_veteran_name(first_name, last_name)
      [first_name, last_name].compact_blank.join('_')
    end

    def build_body(options = {})
    data = {
      systemName: options[:system_name].presence || 'VA.gov',
      docType: options[:doc_type],
      fileName: options[:file_name],
      trackedItemIds: options[:tracked_item_ids].presence || []
    }
    data[:claimId] = options[:claim_id] unless options[:claim_id].nil?
    data[:participantId] = options[:participant_id] unless options[:participant_id].nil?
    data[:fileNumber] = options[:file_number] unless options[:file_number].nil?
    { data: }
  end
  end
end
