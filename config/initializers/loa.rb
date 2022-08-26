# frozen_string_literal: true

module LOA
  # LOA stands for Level of Assurance
  ONE   = 1
  TWO   = 2
  THREE = 3

  # The AuthnContext values with "/vets" suffix are non-standard but
  # were used by ID.me to distinguish policies for Vets.gov from other
  # VA uses.
  IDME_LOA1_VETS = 'http://idmanagement.gov/ns/assurance/loa/1/vets'
  IDME_LOA2_VETS = 'http://idmanagement.gov/ns/assurance/loa/2/vets'
  IDME_LOA3_VETS = 'http://idmanagement.gov/ns/assurance/loa/3/vets'

  # ID.me and VA are gradually consolidating on the standard LOA-based
  # authentication context values but currently only the LOA3 one is used
  # within vets-api
  IDME_LOA3 = 'http://idmanagement.gov/ns/assurance/loa/3'
  IDME_CLASSIC_LOA3 = 'classic_loa3'

  # MHV accounts with this designation are considered LOA3 level
  MHV_PREMIUM_VERIFIED = %w[Premium].freeze

  # DSLogon accounts with these assurance levels are considered LOA3
  DSLOGON_PREMIUM_VERIFIED = [DSLOGON_ASSURANCE_TWO = '2', DSLOGON_ASSURANCE_THREE = '3'].freeze

  IDME_MHV_LOA1 = 'myhealthevet'
  IDME_MHV_LOA3 = 'myhealthevet_loa3'
  IDME_DSLOGON_LOA1 = 'dslogon'
  IDME_DSLOGON_LOA3 = 'dslogon_loa3'
end
