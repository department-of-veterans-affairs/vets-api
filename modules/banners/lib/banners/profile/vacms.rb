# frozen_string_literal: true

module Banners
  module Profile
    class Vacms
      # Converts the GraphQL response into a hash that can be used to create or update a VACMS banner
      def self.parsed_banner(graphql_banner_response)
        {
          entity_id: graphql_banner_response['entityId'],
          headline: graphql_banner_response['title'],
          alert_type: graphql_banner_response['fieldAlertType'],
          entity_bundle: 'full_width_banner_alert',
          content: graphql_banner_response['fieldBody']['processed'],
          context: graphql_banner_response['fieldBannerAlertVamcs'],
          show_close: graphql_banner_response['fieldAlertDismissable'],
          operating_status_cta: graphql_banner_response['fieldAlertOperatingStatusCta'],
          email_updates_button: graphql_banner_response['fieldAlertEmailUpdatesButton'],
          find_facilities_cta: graphql_banner_response['fieldAlertFindFacilitiesCta'],
          limit_subpage_inheritance: graphql_banner_response['fieldAlertLimitSubpageInheritance'] || false
        }
      end
    end
  end
end
