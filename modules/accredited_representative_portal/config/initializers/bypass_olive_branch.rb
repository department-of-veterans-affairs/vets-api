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
    PATH_NORMALIZER = ::ActionDispatch::Journey::Router::Utils

    def exclude_arp_route?(env)
      ##
      # Our reverse proxy for deployed environments prepends an extra slash at
      # the beginning. Offending nginx conf here:
      # https://github.com/department-of-veterans-affairs/devops/blob/c84a83696357b84e155c8ec849934af3019da769/ansible/deployment/config/revproxy-vagov/templates/nginx_api_server.conf.j2#L121
      #
      path_info = PATH_NORMALIZER.normalize_path(env['PATH_INFO']).to_s
      path_info.start_with?(ARP_PATH_INFO_PREFIX)
    end
  end
end

module OliveBranch
  class Middleware
    prepend AccreditedRepresentativePortal::BypassOliveBranch
  end
end
