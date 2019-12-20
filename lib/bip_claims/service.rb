# frozen_string_literal: true

module BipClaims
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.bip_claims'
    include Common::Client::Monitoring

    configuration BipClaims::Configuration

    def veteran_attributes(claim)
      case claim.form_id
      when '21P-530'
        ssn, full_name, bday = claim.parsed_form.values_at(
          'veteranSocialSecurityNumber',
          'veteranFullName',
          'veteranDateOfBirth'
        )
      end

      BipClaims::Veteran.new(
        ssn: ssn,
        first_name: full_name['first'],
        middle_name: full_name['middle'],
        last_name: full_name['last'],
        birth_date: bday
      )
    end

    def lookup_veteran_from_mvi(claim)
      MVI::AttrService.new.find_profile(veteran_attributes(claim))&.profile
    rescue MVI::Errors::Base
      nil
    end

    def create_claim(form_data)
      veteran_record = lookup_veteran_from_mvi(form_data)
      claimant_record = false # TODO: look up from MVI
      return false unless veteran_record && claimant_record

      submit_claim(veteran: veteran_record, claimant: claimant_record)
    end

    def submit_claim(veteran:, claimant:)
      body = {
        "serviceTypeCode": '',
        "programTypeCode": '',
        "benefitClaimTypeCode": '',
        "claimant": {
          "participantId": claimant&.participantId
        },
        "veteran": {
          "participantId": veteran&.participantId,
          "firstName": '',
          "lastName": ''
        },
        "dateOfClaim": DateTime.now.utc.iso8601
      }
      body
    end

    # TODO: Identify if method is necessary
    def benefit_claim_types(query)
      # /api/v1/claims/benefit_claim_types
    end

    # TODO: per BIP, this health endpoint is subject to change
    # TODO: add auth to request
    def status
      response = request(
        :get,
        'actuator/health'
      )

      response
    end

    # TODO: Breakers set up
    def self.current_breaker_outage?
      last_bc_outage = Breakers::Outage.find_latest(service: BipClaims::Configuration.instance.breakers_service)
      BipClaims::Service.new.status('').try(:status) != 200 if last_bc_outage.present? && last_bc_outage.end_time.blank?
    end
  end
end
