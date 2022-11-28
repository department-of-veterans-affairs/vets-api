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
          page_size = 0 if page_size.nil? # 0 is the default for the VAOS service which means return all clinics
          url = "/vaos/v1/locations/#{location_id}/clinics"
          url_params = {
            'patientIcn' => get_icn(clinical_service),
            'clinicIds' => get_clinic_ids(clinic_ids),
            'clinicalService' => clinical_service,
            'pageSize' => page_size,
            'pageNumber' => page_number
          }.compact
          response = perform(:get, url, url_params, headers)
          response.body[:data].map { |clinic| OpenStruct.new(clinic) }
        end
      end

      def get_available_slots(location_id:, clinic_id:, start_dt:, end_dt:)
        with_monitoring do
          url_path = "/vaos/v1/locations/#{location_id}/clinics/#{clinic_id}/slots"
          url_params = {
            'start' => start_dt,
            'end' => end_dt
          }
          response = perform(:get, url_path, url_params, headers)
          response.body[:data] ? response.body[:data].map { |slot| OpenStruct.new(slot) } : []
        end
      end

      private

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
    end
  end
end
