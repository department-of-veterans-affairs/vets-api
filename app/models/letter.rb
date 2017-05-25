# frozen_string_literal: true
require 'common/models/base'

class Letter < Common::Base
  LETTER_TYPES = {
    benefits_summary: 'BENEFITSUMMARY',
    benefits_summary_dependent: 'BENEFITSUMMARYDEPENDENT',
    benefits_verification: 'BENEFITVERIFICATION',
    civil_service: 'CIVILSERVICE',
    commissary: 'COMMISSARY',
    proof_of_service: 'PROOFOFSERVICE',
    service_verification: 'SERVICEVERIFICATION',
    medicare_part_d: 'MEDICAREPARTD',
    minimum_essential_coverage: 'MINIMUMESSENTIALCOVERAGE'
  }.freeze

  attribute :name, String
  attribute :letter_type, String

  def initialize(init_attributes = {})
    raise ArgumentError, 'invalid letter type' unless LETTER_TYPES.value? init_attributes[:letter_type]
    init_attributes[:letter_type] = LETTER_TYPES.key(init_attributes[:letter_type])
    super(init_attributes)
  end
end
