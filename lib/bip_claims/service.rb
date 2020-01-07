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
      else
        raise ArgumentError, "Unsupported form id: #{claim.form_id}"
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
      veteran = MVI::AttrService.new.find_profile(veteran_attributes(claim))
      if veteran.profile&.participant_id
        StatsD.increment("#{STATSD_KEY_PREFIX}.mvi_lookup_hit")
        veteran.profile
      else
        StatsD.increment("#{STATSD_KEY_PREFIX}.mvi_lookup_miss")
      end
    end
  end
end
