# frozen_string_literal: true

module SimpleFormsApi
  class VBA::Base
    include Virtus.model(nullify_blank: true)
    STATS_KEY = 'api.simple_forms_api.base'

    attribute :data

    def initialize(data)
      @data = data
    end

    def desired_stamps
      []
    end

    def metadata
      raise NotImplementedError, 'Class must implement metadata method'
    end

    def submission_date_stamps(*, **)
      []
    end

    def track_user_identity(confirmation_number)
      return unless identity

      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info("Simple forms api - #{form_number} submission user identity", identity:, confirmation_number:)
    end

    def zip_code_is_us_based
      country ? country == 'USA' : true
    end

    def handle_attachments(*, **); end

    private

    attr_reader :identity, :country

    def fetch_nested_value(*args)
      args.each do |key_path|
        result = @data.dig(*key_path)
        return result if result
      end
      nil
    end
  end
end
