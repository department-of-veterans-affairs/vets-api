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
  end
end
