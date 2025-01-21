# frozen_string_literal: true

module SimpleFormsApi
  module NotificationEmail
    class Personalization
      attr_reader :form_data, :form_number, :confirmation_number, :date_submitted, :expiration_date,
                  :lighthouse_updated_at

      def initialize(config)
        @form_data = config[:form_data]
        @form_number = config[:form_number]
        @confirmation_number = config[:confirmation_number]
        @date_submitted = config[:date_submitted]
        @expiration_date = config[:expiration_date]
        @lighthouse_updated_at = config[:lighthouse_updated_at]
      end

      def as_hash
        {
          'first_name' => "SimpleFormsApi::#{form_number.titleize.gsub(' ', '')}".constantize.new(form_data).first_name,
          'confirmation_number' => confirmation_number,
          'date_submitted' => date_submitted,
          'lighthouse_updated_at' => lighthouse_updated_at
        }
      end
    end
  end
end
