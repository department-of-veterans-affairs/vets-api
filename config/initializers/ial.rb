# frozen_string_literal: true

module IAL
  ONE   = 1
  TWO   = 2

  # Login.gov uses IAL for authentication standards
  LOGIN_GOV_IAL1 = 'http://idmanagement.gov/ns/assurance/ial/1'
  LOGIN_GOV_IAL2 = 'http://idmanagement.gov/ns/assurance/ial/2'

  # Some inbound logins originate from Salesforce with '2fa'/'mfa' appended.
  LOGIN_GOV_IAL1_2FA = 'http://idmanagement.gov/ns/assurance/ial/1/2fa'
  LOGIN_GOV_IAL1_MFA = 'http://idmanagement.gov/ns/assurance/ial/1/mfa'
  LOGIN_GOV_IAL2_2FA = 'http://idmanagement.gov/ns/assurance/ial/2/2fa'
  LOGIN_GOV_IAL2_MFA = 'http://idmanagement.gov/ns/assurance/ial/2/mfa'

  IDME_IAL2 = 'http://idmanagement.gov/ns/assurance/ial/2/aal/2'
end
