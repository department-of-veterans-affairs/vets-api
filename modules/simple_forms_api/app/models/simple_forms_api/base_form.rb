# frozen_string_literal: true

module SimpleFormsApi
  module BaseForm
    def signature_date
      @signature_date ||= Time.current.in_time_zone('America/Chicago')
    end
  end
end
