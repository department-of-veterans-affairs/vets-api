# frozen_string_literal: true

require 'sentry_logging'
require 'common/exceptions/bad_gateway'
require 'common/exceptions/unprocessable_entity'

# We may receive user input for preferred_facility in one of several forms. We need to transform them into a
# consistent facility_id to submit to enrolllment.
# 1. A correct "vha_<facility_id>" code. In this case we just need to strip the "vha_" prefix.
# 2. A facility name. Because of a frontend bug some submissions came through with the facility name instead
#    of ID. We can reverse map these back to IDs. BUT, there are 2 pairs of facilities with duplicate names, so
#    in those cases we need to disambiguate based on figuring out which facilty is closer to the supplied zip.
# 3. nil or empty string, because of a frontend bug that allowed users to not select a facility even when presented
#    with a list of suggestions. In those cases we will pick the closest facility from the suggestion service.
# 4. nil or empty string because the supplied zip was invalid and no facility can be determined. In those cases
#    we will return nil and the registration will flow through to enrollment with no preferred facility.
module CovidVaccine
  module V0
    class FacilityResolver
      include SentryLogging

      def resolve(submission)
        supplied_value = submission.raw_form_data['preferred_facility']
        supplied_zip = submission.raw_form_data['zip_code']
        return supplied_value.delete_prefix('vha_') if supplied_value&.start_with?('vha_')

        return id_for_facility(supplied_value, supplied_zip) if supplied_value&.present?

        id_for_zip(supplied_zip)
      rescue Common::Exceptions::UnprocessableEntity
        nil
      rescue => e
        log_exception_to_sentry(e)
        nil
      end

      private

      def id_for_zip(zip)
        suggestions = CovidVaccine::V0::FacilitySuggestionService.new.facilities_for(zip, 5)
        suggestions.map { |x| x[:id].delete_prefix('vha_') }.first
      end

      def id_for_facility(name, zip)
        mapped_ids = COVID_VACCINE_FACILITY_NAME_MAP[name]
        return mapped_ids.first if mapped_ids&.length == 1

        return disambiguate_ids(mapped_ids, zip) if mapped_ids && mapped_ids.length > 1

        log_message_to_sentry("Unknown non-empty facility value #{name}") if mapped_ids.blank?
        nil
      end

      def disambiguate_ids(ambiguous_ids, zip)
        suggestions = CovidVaccine::V0::FacilitySuggestionService.new.facilities_for(zip, 5)
        suggestions.map { |x| x[:id].delete_prefix('vha_') }.detect { |id| ambiguous_ids.include?(id) }
      end
    end
  end
end
