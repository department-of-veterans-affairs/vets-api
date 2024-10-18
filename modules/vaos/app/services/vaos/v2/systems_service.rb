# frozen_string_literal: true

module VAOS
  module V2
    class SystemsService < VAOS::SessionService
      def get_facility_clinics(location_id:,
                               clinical_service: nil,
                               clinic_ids: nil,
                               page_size: nil,
                               page_number: nil)
        with_monitoring do
          response = get_clinics(location_id:, clinical_service:, clinic_ids:, page_size:, page_number:)
          response.body[:data].map { |clinic| OpenStruct.new(clinic) }
        end
      end

      def get_available_slots(location_id:, clinic_id:, clinical_service:, start_dt:, end_dt:)
        with_monitoring do
          response = if Flipper.enabled?(:va_online_scheduling_use_vpg, user) &&
                        Flipper.enabled?(:va_online_scheduling_enable_OH_slots_search, user)
                       get_slots_vpg(location_id:, clinic_id:, clinical_service:, start_dt:, end_dt:)
                     else
                       get_slots_vaos(location_id:, clinic_id:, start_dt:, end_dt:)
                     end

          response.body[:data] ? response.body[:data].map { |slot| OpenStruct.new(slot) } : []
        end
      end

      private

      def get_clinics(location_id:, clinical_service:, clinic_ids:, page_size:, page_number:)
        page_size = 0 if page_size.nil? # 0 is the default for the VAOS service which means return all clinics
        url = if Flipper.enabled?(:va_online_scheduling_use_vpg, user)
                "/vpg/v1/locations/#{location_id}/clinics"
              else
                "/#{base_vaos_route}/locations/#{location_id}/clinics"
              end

        url_params = {
          'patientIcn' => get_icn(clinical_service),
          'clinicIds' => get_clinic_ids(clinic_ids),
          'clinicalService' => clinical_service,
          'pageSize' => page_size,
          'pageNumber' => page_number
        }.compact

        #  'clinicalService' is used when retrieving clinics for appointment scheduling,
        #  triggering stop code filtering to avoid displaying unavailable clinics.
        url_params.merge!('enableStopCodeFilter' => true) if url_params['clinicalService'].present?
        perform(:get, url, url_params, headers)
      end

      # Patient icn is only valid if the clinical service is of type primary care.
      def get_icn(clinical_service)
        clinical_service == 'primaryCare' ? user.icn : nil
      end

      # Depending on how the clinic ids array query parameter is passed in rails can see it
      # internally as an array or a comma separated string. VAOS Service will only accept a
      # CSV string of clinic ids. This method will convert the clinic ids to a csv string if not
      # one already.
      def get_clinic_ids(ids)
        ids.is_a?(Array) ? ids.to_csv(row_sep: nil) : ids
      end

      def get_slots_vaos(location_id:, clinic_id:, start_dt:, end_dt:)
        url_path = "/#{base_vaos_route}/locations/#{location_id}/clinics/#{clinic_id}/slots"
        url_params = {
          'start' => start_dt,
          'end' => end_dt
        }
        perform(:get, url_path, url_params, headers)
      end

      def get_slots_vpg(location_id:, clinic_id:, clinical_service:, start_dt:, end_dt:)
        url_path = '/vpg/v1/slots'
        url_params = {
          'start' => start_dt,
          'end' => end_dt,
          'clinic' => clinic_id,
          'clinicalService' => clinical_service,
          'location' => location_id
        }.compact

        perform(:get, url_path, url_params, headers)
      end
    end
  end
end
