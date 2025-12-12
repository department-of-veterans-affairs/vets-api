# frozen_string_literal: true

module Chatbot
  module RequiresEdipi
    extend ActiveSupport::Concern

    private

    def ensure_edipi_present
      profile = resolve_mpi_profile_for_edipi
      return if profile.respond_to?(:edipi) && profile.edipi.present?

      Rails.logger.warn(
        'Chatbot::RequiresEdipi missing EDIPI, responding with empty payload ' \
        "icn=#{safe_icn_for_logging}, mpi=#{profile.inspect}"
      )
      render json: empty_edipi_payload_for(action_name), status: :ok
    end

    def resolve_mpi_profile_for_edipi
      if respond_to?(:mpi_profile, true)
        send(:mpi_profile)
      elsif respond_to?(:fetch_mpi_profile, true)
        send(:fetch_mpi_profile)
      end
    end

    def empty_edipi_payload_for(action_name)
      base_meta = { sync_status: 'SUCCESS' }

      case action_name.to_s
      when 'index'
        { data: [], meta: base_meta }
      when 'show'
        { data: nil, meta: base_meta }
      else
        { data: nil, meta: base_meta }
      end
    end

    def safe_icn_for_logging
      if respond_to?(:icn, true)
        send(:icn)
      elsif instance_variable_defined?(:@icn)
        instance_variable_get(:@icn)
      end
    end
  end
end
