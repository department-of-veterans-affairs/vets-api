# frozen_string_literal: true

module Mobile
  module V0
    class DecisionLetterSerializer
      include FastJsonapi::ObjectSerializer

      set_type :decisionLetter
      set_id :document_id

      attributes :series_id,
                 :version,
                 :type_description,
                 :type_id,
                 :doc_type,
                 :subject,
                 :received_at,
                 :source,
                 :mime_type,
                 :alt_doc_types,
                 :restricted,
                 :upload_date
    end
  end
end
