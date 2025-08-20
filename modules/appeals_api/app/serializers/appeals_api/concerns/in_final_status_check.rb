module AppealsApi::Concerns::InFinalStatusCheck
  extend ActiveSupport::Concern
  FINAL_SUCCESS_STATUS_KEY = 'final_success_status'

  included do 
    attribute :in_final_status?
  end

  def in_final_status?
  # TODO: Improve true/false classification for submissions in "error" status
  #       Non-recoverable errors should return true and recoverable errors false
  return true if status == 'vbms' ||
                  status == 'expired' ||
                  (status == 'success' && metadata[FINAL_SUCCESS_STATUS_KEY].present?) ||
                  (status == 'error' && code.start_with?('DOC1')) # non-upstream errors only

    false
  end
end