# frozen_string_literal: true

module Chatbot
  module RequiresEdipi
    extend ActiveSupport::Concern

    private

    def ensure_edipi_present
      profile = resolve_mpi_profile_for_edipi
      return if profile.respond_to?(:edipi) && profile.edipi.present?

      Rails.logger.warn(
        'Chatbot::RequiresEdipi missing EDIPI, responding with empty payload'
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

      # if needed, the response structure can be passed in from upstream
      # controller instead of hardcoding like this
      case action_name.to_s
      when 'index'
        { data: [], meta: base_meta }
      when 'show'
        { data: nil, meta: base_meta }
      else
        raise ArgumentError, "Unsupported action for EDIPI guard: #{action_name}"
      end
    end
  end
end
