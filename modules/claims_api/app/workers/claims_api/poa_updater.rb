# frozen_string_literal: true

require 'sidekiq'
require 'bgs'

module ClaimsApi
  class PoaUpdater
    include Sidekiq::Worker

    def perform(_power_of_attorney_id, participant_id)
      # Get claimsapipowerofattorney
      poa_form = {}
      service = BGS::Services.new
      service.manage_representative.update_poa_relationship(
        date_request_accepted: poa_form.created_at,
        participant_id: participant_id,
        ssn: poa_form.auth_headers['X-VA-SSN'],
        poa_code: poa_form.form_data['poaCode']
      )
    end
  end
end
