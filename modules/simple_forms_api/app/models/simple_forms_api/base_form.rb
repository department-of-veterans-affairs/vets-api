# frozen_string_literal: true

module SimpleFormsApi
  class BaseForm
    include Virtus.model(nullify_blank: true)

    attribute :data

    attr_accessor :signature_date

    def initialize(data)
      @data = data
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
