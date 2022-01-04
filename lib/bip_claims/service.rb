# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'mpi/service'
require_relative 'configuration'
require_relative 'veteran'

module BipClaims
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.bip_claims'
    include Common::Client::Concerns::Monitoring

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

    def lookup_veteran_from_mpi(claim)
      veteran = MPI::Service.new.find_profile(veteran_attributes(claim))
      if veteran.profile&.participant_id
        StatsD.increment("#{STATSD_KEY_PREFIX}.mvi_lookup_hit")
        veteran.profile
      else
        StatsD.increment("#{STATSD_KEY_PREFIX}.mvi_lookup_miss")
        nil
      end
    end
  end
end
