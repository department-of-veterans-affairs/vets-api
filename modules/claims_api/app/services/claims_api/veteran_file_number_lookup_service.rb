# frozen_string_literal: true

require 'bgs_service/person_web_service'
require 'bgs_service/local_bgs'
require 'claims_api/claim_logger'

module ClaimsApi
  class VeteranFileNumberLookupService
    UNABLE_TO_LOCATE_ERROR_MESSAGE = "Unable to locate Veteran's File Number in Master Person Index (MPI). " \
                                     'Please submit an issue at ask.va.gov ' \
                                     'or call 1-800-MyVA411 (800-698-2411) for assistance.'
    BGS_ERROR_MESSAGE = "A BGS failure occurred while trying to retrieve Veteran 'FileNumber'"

    def initialize(veteran_ssn, participant_id)
      @veteran_ssn = veteran_ssn
      @participant_id = participant_id
    end

    def check_file_number_exists!
      response = find_by_ssn_bgs_call
      file_number = response&.dig(:file_nbr)

      unless response && file_number.present?
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: UNABLE_TO_LOCATE_ERROR_MESSAGE
        )
      end

      file_number
    rescue BGS::ShareError
      ClaimsApi::Logger.log('poa_find_by_ssn', message: BGS_ERROR_MESSAGE)
      raise ::Common::Exceptions::FailedDependency
    end

    private

    def find_by_ssn_bgs_call
      # rubocop:disable Rails/DynamicFindBy
      ClaimsApi::PersonWebService.new(
        external_uid: @participant_id,
        external_key: @participant_id
      ).find_by_ssn(@veteran_ssn)
      # rubocop:enable Rails/DynamicFindBy
    end
  end
end
