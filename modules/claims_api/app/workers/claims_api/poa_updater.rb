# frozen_string_literal: true

require 'sidekiq'
require 'lighthouse-bgs'

module ClaimsApi
  class PoaUpdater
    include Sidekiq::Worker

    def perform(power_of_attorney_id, participant_id)
      poa_form = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      service = LighthouseBGS::Services.new
      service.manage_representative.update_poa_relationship(
        date_request_accepted: poa_form.created_at,
        participant_id: participant_id,
        ssn: poa_form.auth_headers['X-VA-SSN'],
        poa_code: poa_form.form_data['poaCode']
      )
      # update status on poa_form
      # I'm assuming this will be something different like a constant
      # in the final implementation
      poa_form.status = 'approved'
      poa_form.save
    end
  end
end