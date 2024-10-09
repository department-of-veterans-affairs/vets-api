module SimpleFormsApi
  module BaseForm
    def signature_date
      Time.current.in_time_zone('America/Chicago')
    end
  end
end
