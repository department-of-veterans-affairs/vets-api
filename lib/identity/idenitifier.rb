# frozen_string_literal: true 

module Identity
  class Identifier 

    KINDS = %w[
      idme_id
      participant_id
      burls_id
      mhv_icn
      mhv_correlation_id
      dslogon_edipi
      sec_id
    ]

    attribute :kind, String
    attribute :value, String

    validates :kind, inclusion: { in: KINDS }

  end
end