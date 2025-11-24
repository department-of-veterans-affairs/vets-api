# frozen_string_literal: true

require 'va_profile/profile/v3/service'

module V0
  module Profile
    class ContactsController < ApplicationController
      service_tag 'profile'
      before_action { authorize :vet360, :access? }

      # GET /v0/profile/contacts
      def index
        start_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        log_upstream_request_start

        response = service.get_health_benefit_bio

        contacts_count = response.contacts&.length || 0
        response_ok = response.ok?
        log_upstream_request_finish(start_ms:, contacts_count:, response_ok:)

        render json: ContactSerializer.new(response.contacts), status: response.status
      rescue => e
        log_exception(start_ms:, e:)
        raise
      end

      private

      def service
        VAProfile::Profile::V3::Service.new(current_user)
      end

      def log_upstream_request_start
        Rails.logger.info(
          event: 'profile.contacts.request.start',
          request_id: request.request_id,
          user_uuid: current_user.uuid,
          icn_present: current_user.icn.present?,
          idme_uuid_present: current_user.idme_uuid.present?,
          logingov_uuid_present: current_user.logingov_uuid.present?
        )
      end

      def log_upstream_request_finish(start_ms:, contacts_count:, response_ok:)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start_ms
        Rails.logger.info(
          event: 'profile.contacts.request.finish',
          request_id: request.request_id,
          upstream_status: response.status,
          contacts_count:,
          ok: response_ok,
          empty: contacts_count.zero?,
          latency_ms: elapsed
        )
        StatsD.measure('profile.contacts.latency', elapsed)
        StatsD.increment('profile.contacts.empty') if contacts_count.zero?
        StatsD.increment('profile.contacts.success') if response.ok?
      end

      def log_exception(start_ms:, e:)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start_ms
        event = if e.is_a?(Common::Exceptions::BackendServiceException)
                  'profile.contacts.backend_error'
                else
                  'profile.contacts.unhandled_error'
                end
        Rails.logger.error(
          event:,
          request_id: request.request_id,
          error_class: e.class.name,
          message: e.message,
          latency_ms: elapsed
        )
        StatsD.increment('profile.contacts.error')
      end
    end
  end
end
