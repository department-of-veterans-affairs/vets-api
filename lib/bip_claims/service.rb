# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'mpi/service'
require_relative 'configuration'

module BipClaims
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.bip_claims'
    include Common::Client::Concerns::Monitoring

    configuration BipClaims::Configuration

    def veteran_attributes(claim)
      case claim.form_id
      when '21P-530EZ'
        ssn, full_name, bday = claim.parsed_form.values_at(
          'veteranSocialSecurityNumber',
          'veteranFullName',
          'veteranDateOfBirth'
        )
      else
        raise ArgumentError, "Unsupported form id: #{claim.form_id}"
      end

      {
        ssn: ssn&.gsub(/\D/, ''),
        first_name: full_name['first'],
        last_name: full_name['last'],
        birth_date: bday
      }
    end

    def lookup_veteran_from_mpi(claim)
      attributes_hash = veteran_attributes(claim)
      veteran = MPI::Service.new.find_profile_by_attributes(first_name: attributes_hash[:first_name],
                                                            last_name: attributes_hash[:last_name],
                                                            birth_date: attributes_hash[:birth_date],
                                                            ssn: attributes_hash[:ssn])
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
