# frozen_string_literal: true

require 'vets/model'

module SimpleFormsApi
  class BaseForm
    include Vets::Model

    attribute :data, Hash

    attr_accessor :signature_date

    def initialize(data)
      # Convert data to an unsafe hash if it is not already a Hash.
      # This is necessary to handle cases where data might be an instance of
      # ActionController::Parameters or similar. Ensure that the input is sanitized
      # before this point to avoid potential security risks.
      data = data&.to_unsafe_h unless data.is_a?(Hash)
      super({ data: })
      @signature_date = Time.current.in_time_zone('America/Chicago')
    end

    def notification_first_name
      data.dig('veteran_full_name', 'first')
    end

    def notification_email_address
      data.dig('veteran', 'email')
    end

    def should_send_to_point_of_contact?
      false
    end
  end
end
