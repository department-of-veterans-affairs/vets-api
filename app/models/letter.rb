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

  # def initialize(name, letter_type)
  #   raise ArgumentError, 'invalid letter type' unless LETTER_TYPES.value? letter_type
  #   @name = name
  #   @letter_type = LETTER_TYPES.key(letter_type).to_s
  #   super
  # end

  def initialize(init_attributes = {})
    super(init_attributes)
    raise ArgumentError, 'invalid letter type' unless LETTER_TYPES.value? @letter_type
  end
end
