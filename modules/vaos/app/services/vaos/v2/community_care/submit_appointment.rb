# frozen_string_literal: true

module VAOS
  module V2
    module CommunityCare
      class SubmitAppointment
        include VAOS::CommunityCareConstants

        APPT_CREATION_SUCCESS_METRIC = "#{STATSD_PREFIX}.appointment_creation.success".freeze
        APPT_CREATION_FAILURE_METRIC = "#{STATSD_PREFIX}.appointment_creation.failure".freeze
        APPT_CREATION_DURATION_METRIC = "#{STATSD_PREFIX}.appointment_creation.duration".freeze

        attr_reader :appointment, :error, :error_code

        def self.call(current_user, params)
          new(current_user, params).call
        end

        def initialize(current_user, params)
          @current_user = current_user
          @params = params
          @appointment = nil
          @error = nil
          @error_code = nil
        end

        def call
          resolve_type_of_care
          submit
          self
        rescue
          record_metric(APPT_CREATION_FAILURE_METRIC)
          raise
        end

        def type_of_care
          @type_of_care || 'no_value'
        end

        private

        attr_reader :current_user, :params

        def resolve_type_of_care
          @type_of_care = get_type_of_care_for_metrics(params[:referral_number])
        rescue
          Rails.logger.error('Failed to retrieve type of care for metrics')
          @type_of_care = 'no_value'
        end

        def submit
          args = build_submit_args
          result = eps_appointment_service.submit_appointment(params[:id], args)

          if result[:error]
            @error = result[:error]
            @error_code = result[:error]
            record_metric(APPT_CREATION_FAILURE_METRIC)
          else
            @appointment = result
            log_referral_booking_duration(params[:referral_number])
            record_metric(APPT_CREATION_SUCCESS_METRIC)
          end
        end

        def build_submit_args
          args = {
            referral_number: params[:referral_number],
            network_id: params[:network_id],
            provider_service_id: params[:provider_service_id],
            slot_ids: [params[:slot_id]]
          }

          patient_attrs = patient_attributes(params)
          args[:additional_patient_attributes] = patient_attrs if patient_attrs.present?
          args
        end

        def patient_attributes(attrs)
          {
            name: {
              family: attrs.dig(:name, :family),
              given: attrs.dig(:name, :given)
            }.compact.presence,
            phone: attrs[:phone_number],
            email: attrs[:email],
            birth_date: attrs[:birth_date],
            gender: attrs[:gender],
            address: {
              line: attrs.dig(:address, :line),
              city: attrs.dig(:address, :city),
              state: attrs.dig(:address, :state),
              country: attrs.dig(:address, :country),
              postal_code: attrs.dig(:address, :postal_code),
              type: attrs.dig(:address, :type)
            }.compact.presence
          }.compact
        end

        def get_type_of_care_for_metrics(referral_number)
          return 'no_value' if referral_number.blank?

          cached_referral = ccra_referral_service.get_cached_referral_data(referral_number, current_user.icn)
          sanitize_log_value(cached_referral&.category_of_care)
        rescue Redis::BaseError
          'no_value'
        end

        def sanitize_log_value(value)
          return 'no_value' if value.blank?

          value.to_s.gsub(/\s+/, '_')
        end

        def log_referral_booking_duration(referral_number)
          start_time = ccra_referral_service.get_booking_start_time(referral_number, current_user.icn)
          return unless start_time

          duration = (Time.current.to_f - start_time) * 1000
          StatsD.histogram(APPT_CREATION_DURATION_METRIC, duration, tags: [COMMUNITY_CARE_SERVICE_TAG])
        rescue => e
          Rails.logger.error("Failed to log referral booking duration: #{e.class} - #{e.message}")
        end

        def record_metric(metric)
          StatsD.increment(metric, tags: [COMMUNITY_CARE_SERVICE_TAG, "type_of_care:#{type_of_care}"])
        end

        def eps_appointment_service
          @eps_appointment_service ||= Eps::AppointmentService.new(current_user)
        end

        def ccra_referral_service
          @ccra_referral_service ||= Ccra::ReferralService.new(current_user)
        end
      end
    end
  end
end
