# frozen_string_literal: true

module Mobile
  module V0
    class DiagnosticReportsSerializer
      include JSONAPI::Serializer

      set_type :diagnostic_report

      attributes :category,
                 :code,
                 :subject,
                 :effectiveDateTime,
                 :issued,
                 :result
    end
  end
end
