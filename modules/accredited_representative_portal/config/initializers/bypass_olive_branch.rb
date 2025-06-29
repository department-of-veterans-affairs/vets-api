# frozen_string_literal: true

module AccreditedRepresentativePortal
  ##
  # `olive_branch` transforms (a) request and (b) response payloads.
  #
  # (a) It deeply transforms request and query param keys.
  # At times it is convenient for params to act as snake-cased setters at a Ruby
  # interface, but not always. Form resources are a possible example where not.
  #
  # For now, let's wait to encounter the cases where we really want this
  # convenience. If we do encounter some, we may discover that we want a more
  # explicit and collocated way to opt in.
  #
  # (b) It reloads the response from JSON, deeply transforms keys, and dumps
  # back to JSON.
  # This is superfluous because our serialization layer `jsonapi-serializer`
  # already has a configuration option for key casing. This realizes our desired
  # casing the one and only time it is visiting an object during serialization.
  #
  module BypassOliveBranch
    def call(env)
      exclude_arp_route?(env) ? @app.call(env) : super
    end

    private

    ARP_PATH_INFO_PREFIX = '/accredited_representative_portal'

    def exclude_arp_route?(env)
      if env_check && Flipper.enabled?(:accredited_representative_portal_normalize_path)
        # Chose the function Rack::Attack::PathNormalizer.normalize_path() since our middlewares
        # uses this later [here](https://github.com/department-of-veterans-affairs/vets-api/blob/934424f5fe986befc33645cfc7b0a3156f3f7ae3/config/application.rb#L88).
        # Need to use this since the Staging path includes an extra hash EX: '//accredited_representative_portal'
        Rack::Attack::PathNormalizer.normalize_path(env['PATH_INFO']).to_s.start_with?(ARP_PATH_INFO_PREFIX)
      else
        env['PATH_INFO'].to_s.start_with?(ARP_PATH_INFO_PREFIX)
      end
    end

    def env_check
      %w[test localhost development staging].include?(Settings.vsp_environment)
    end
  end
end

module OliveBranch
  class Middleware
    prepend AccreditedRepresentativePortal::BypassOliveBranch
  end
end
