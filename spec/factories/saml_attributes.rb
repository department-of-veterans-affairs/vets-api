# frozen_string_literal: true

FactoryBot.define do
  factory :idme_loa1, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'http://idmanagement.gov/ns/assurance/loa/1/vets' }
    end
    uuid { ['0e1bb5723d7c4f0686f46ca4505642ad'] }
    email { ['kam+tristanmhv@adhocteam.us'] }
    multifactor { [false] }
    level_of_assurance { ['1'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :idme_loa3, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'http://idmanagement.gov/ns/assurance/loa/3/vets' }
    end
    uuid { ['0e1bb5723d7c4f0686f46ca4505642ad'] }
    email { ['kam+tristanmhv@adhocteam.us'] }
    fname { ['Tristan'] }
    lname { ['MHV'] }
    mname { [''] }
    social { ['111223333'] }
    gender { ['male'] }
    birth_date { ['1735-10-30'] }
    multifactor { [true] } # always true for these types
    level_of_assurance { ['3'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :mhv_basic, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'myhealthevet' }
    end
    mhv_icn { [''] }
    mhv_profile { ['{"accountType":"Basic"}'] }
    mhv_uuid { ['12345748'] }
    email { ['kam+tristanmhv@adhocteam.us'] }
    multifactor { [false] }
    uuid { ['0e1bb5723d7c4f0686f46ca4505642ad'] }
    level_of_assurance { ['0'] } # TODO: check this is idme_loa

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :mhv_advanced, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'myhealthevet' }
    end
    mhv_icn { ['1012853550V207686'] }
    mhv_profile { ['{"accountType":"Advanced"}'] }
    mhv_uuid { ['12345748'] }
    email { ['kam+tristanmhv@adhocteam.us'] }
    multifactor { [false] }
    uuid { ['0e1bb5723d7c4f0686f46ca4505642ad'] }
    level_of_assurance { ['0'] } # TODO: check this is idme_loa

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :mhv_premium, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'myhealthevet' }
    end
    mhv_icn { ['1012853550V207686'] }
    mhv_profile {
      [
        '{"accountType":"Premium","availableServices":{"21":"VA Medications",' \
        '"4":"Secure Messaging","3":"VA Allergies","2":"Rx Refill",' \
        '"12":"Blue Button (all VA data)","1":"Blue Button self entered data.",' \
        '"11":"Blue Button (DoD) Military Service Information"}}'
      ]
    }
    mhv_uuid { ['12345748'] }
    email { ['kam+tristanmhv@adhocteam.us'] }
    multifactor { [false] }
    uuid { ['0e1bb5723d7c4f0686f46ca4505642ad'] }
    level_of_assurance { ['0'] } # TODO: check this is idme_loa

    initialize_with { new(attributes.stringify_keys) }
  end

  # TODO: is this by definition identical to the idme_loa3 factory
  factory :mhv_loa3, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'myhealthevet_loa3' }
    end
    uuid { ['0e1bb5723d7c4f0686f46ca4505642ad'] }
    email { ['kam+tristanmhv@adhocteam.us'] }
    fname { ['Tristan'] }
    lname { ['MHV'] }
    mname { [''] }
    social { ['111223333'] }
    gender { ['male'] }
    birth_date { ['1735-10-30'] }
    multifactor { [true] } # always true for these types
    level_of_assurance { ['3'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :dslogon_level1, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'dslogon' }
    end
    dslogon_status { [] }
    dslogon_assurance { ['1'] }
    dslogon_gender { [] }
    dslogon_deceased { [] }
    dslogon_idtype { [] }
    uuid { ['0e1bb5723d7c4f0686f46ca4505642ad'] }
    dslogon_uuid { ['1606997570'] }
    email { ['kam+tristanmhv@adhocteam.us'] }
    multifactor { [false] }
    level_of_assurance { ['0'] }
    dslogon_birth_date { [] }
    dslogon_fname { [] }
    dslogon_lname { [] }
    dslogon_mname { [] }
    dslogon_idvalue { [] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :dslogon_level2, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'dslogon' }
    end
    dslogon_status { ['DEPENDENT'] }
    dslogon_assurance { ['2'] }
    dslogon_gender { ['M'] }
    dslogon_deceased { ['false'] }
    dslogon_idtype { ['ssn'] }
    uuid { ['0e1bb5723d7c4f0686f46ca4505642ad'] }
    dslogon_uuid { ['1606997570'] }
    email { ['kam+tristanmhv@adhocteam.us'] }
    multifactor { [false] }
    level_of_assurance { ['0'] }
    dslogon_birth_date { ['1735-10-30'] }
    dslogon_fname { ['Tristan'] }
    dslogon_lname { ['MHV'] }
    dslogon_mname { [''] }
    dslogon_idvalue { ['111223333'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_unmappable_response, class: 'OneLogin::RubySaml::Attributes' do
    iam_eai_auth_level { ['[Filtered]'] }
    am_eai_ext_user_groups { ['[Filtered]'] }
    am_eai_ext_user_id { ['[Filtered]'] }
    am_eai_fim_xattrs { ['mapper_error,jstrackinguuid'] }
    jstrackinguuid { ['Track-Yw4ggABCFl'] }
    mapper_error { ['PRINCIPAL SEC_ID is NULL/EMPTY OR NOT FOUND for VA gov (vagov)'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_logingov_ial1, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { IAL::LOGIN_GOV_IAL1 }
    end
    va_eauth_csid { ['LOGINGOV'] }
    va_eauth_lastname { ['NOT_FOUND'] }
    va_eauth_ial { ['1'] }
    va_eauth_firstname { ['NOT_FOUND'] }
    va_eauth_csponly { ['true'] }
    va_eauth_authenticationMethod { ['http://idmanagement.gov/ns/assurance/ial/1'] }
    va_eauth_aal { ['2'] }
    va_eauth_emailaddress { ['testemail@test.com'] }
    va_eauth_transactionid { ['VaxGP1nMv39/NeLQsr01Lg056gaHCchCiMmIf2kpUhs='] }
    va_eauth_authncontextclassref { ['http://idmanagement.gov/ns/assurance/ial/1'] }
    va_eauth_uid { ['54e78de6140d473f87960f211be49c08'] }
    va_eauth_issueinstant { ['2020-02-05T21:14:20Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_verifiedAt { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_logingov_ial2, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { IAL::LOGIN_GOV_IAL2 }
    end
    va_eauth_phone { ['(123)123-1234'] }
    va_eauth_lastname { ['TESTER'] }
    va_eauth_ial { ['2'] }
    va_eauth_icn { ['1200049153V217987'] }
    va_eauth_city { ['Seattle'] }
    va_eauth_country { ['NOT_FOUND'] }
    va_eauth_csp_identifier { ['200VLGN'] }
    va_eauth_gender { ['MALE'] }
    va_eauth_street2 { ['NOT_FOUND'] }
    va_eauth_aal { ['2'] }
    va_eauth_csp_method { ['LOGINGOV'] }
    va_eauth_dodedipnid { ['NOT_FOUND'] }
    va_eauth_emailaddress { ['vets.gov.user+1000@example.com'] }
    va_eauth_cspid { ['200VLGN_65f9f3b5-5449-47a6-b272-9d6019e7c2e3'] }
    va_eauth_issueinstant { ['2021-11-10T18:47:50Z'] }
    va_eauth_birthDate_v1 { ['19820412'] }
    va_eauth_middlename { ['LOGIN'] }
    va_eauth_state { ['WA'] }
    va_eauth_birlsfilenumber { ['NOT_FOUND'] }
    va_eauth_postalcode { ['39876'] }
    va_eauth_street3 { ['NOT_FOUND'] }
    va_eauth_proofingAuthority { ['FICAM'] }
    va_eauth_pid { ['NOT_FOUND'] }
    va_eauth_csid { ['LOGINGOV'] }
    va_eauth_pnidtype { ['SSN'] }
    va_eauth_mcid { ['WSSOE2111101347520361419017657'] }
    va_eauth_firstname { ['ROBERT'] }
    va_eauth_prefix { ['NOT_FOUND'] }
    va_eauth_street { ['123 Fantasy Lane'] }
    va_eauth_csponly { ['false'] }
    va_eauth_pnid { ['123123123'] }
    va_eauth_commonname { ['vets.gov.user+1000@example.com'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_suffix { ['NOT_FOUND'] }
    va_eauth_uid { ['aa478abc-e494-4af1-9f87-d002f8fe1cda'] }
    va_eauth_isDelegate { ['false'] }
    va_eauth_secid { ['1200049153'] }
    va_eauth_gcIds {
      ['1200049153V217987^NI^200M^USVHA^P|' \
       '65f9f3b5-5449-47a6-b272-9d6019e7c2e3^PN^200VLGN^USDVA^A|' \
       'aa478abc-e494-4af1-9f87-d002f8fe1cda^PN^200VLGN^USDVA^A|' \
       '123456^PI^200MHS^USVHA^A|' \
       '1200049153^PN^200PROV^USDVA^A|' \
       '1200049153^PN^200PROV^USDVA^A|987656789^PI^200M^USVHA^P|' \
       '123456789^PI^200M^USVHA^P']
    }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_npi { ['NOT_FOUND'] }
    va_eauth_street1 { ['123 Fantasy Lane'] }
    va_eauth_verifiedAt { ['2021-10-28T23:54:46Z'] }
    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_idme_loa1_unproofed, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { LOA::IDME_LOA1_VETS }
    end
    va_eauth_csid { ['idme'] }
    va_eauth_lastname { ['GPKTESTNINE'] }
    va_eauth_aal_idme_highest { ['2'] }
    va_eauth_credentialassurancelevel { ['1'] }
    va_eauth_ial { ['1'] }
    va_eauth_firstname { ['JERRY'] }
    va_eauth_ial_idme_highest { ['1'] }
    va_eauth_csponly { ['true'] }
    va_eauth_authenticationMethod { ['http://idmanagement.gov/ns/assurance/loa/1/vets'] }
    va_eauth_aal { ['2'] }
    va_eauth_emailaddress { ['vets.gov.user+262@example.com'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_authncontextclassref { ['http://idmanagement.gov/ns/assurance/loa/1/vets'] }
    va_eauth_uid { ['54e78de6140d473f87960f211be49c08'] }
    va_eauth_issueinstant { ['2020-02-05T21:14:20Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_idme_loa1, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { LOA::IDME_LOA1_VETS }
    end
    va_eauth_csid { ['idme'] }
    va_eauth_lastname { ['GPKTESTNINE'] }
    va_eauth_aal_idme_highest { ['2'] }
    va_eauth_credentialassurancelevel { ['1'] }
    va_eauth_ial { ['1'] }
    va_eauth_firstname { ['JERRY'] }
    va_eauth_ial_idme_highest { ['classic_loa3'] }
    va_eauth_csponly { ['true'] }
    va_eauth_authenticationMethod { ['http://idmanagement.gov/ns/assurance/loa/1/vets'] }
    va_eauth_aal { ['2'] }
    va_eauth_emailaddress { ['vets.gov.user+262@example.com'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_authncontextclassref { ['http://idmanagement.gov/ns/assurance/loa/1/vets'] }
    va_eauth_uid { ['54e78de6140d473f87960f211be49c08'] }
    va_eauth_issueinstant { ['2020-02-05T21:14:20Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # Assertion for user with no multifactor
  factory :ssoe_idme_singlefactor, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { LOA::IDME_LOA1_VETS }
    end
    va_eauth_csid { ['idme'] }
    va_eauth_lastname { ['GPKTESTNINE'] }
    va_eauth_aal_idme_highest { ['1'] }
    va_eauth_credentialassurancelevel { ['1'] }
    va_eauth_ial { ['1'] }
    va_eauth_firstname { ['JERRY'] }
    va_eauth_ial_idme_highest { ['1'] }
    va_eauth_csponly { ['true'] }
    va_eauth_authenticationMethod { ['http://idmanagement.gov/ns/assurance/loa/1/vets'] }
    va_eauth_aal { ['1'] }
    va_eauth_emailaddress { ['vets.gov.user+262@example.com'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_authncontextclassref { ['http://idmanagement.gov/ns/assurance/loa/1/vets'] }
    va_eauth_uid { ['54e78de6140d473f87960f211be49c08'] }
    va_eauth_issueinstant { ['2020-02-05T21:14:20Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_multifactor { ['false'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # Assertion for multifactor enrollment
  factory :ssoe_idme_multifactor, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'multifactor' }
    end
    va_eauth_csid { ['idme'] }
    va_eauth_lastname { ['GPKTESTNINE'] }
    va_eauth_aal_idme_highest { ['2'] }
    va_eauth_credentialassurancelevel { ['1'] }
    va_eauth_ial { ['1'] }
    va_eauth_firstname { ['JERRY'] }
    va_eauth_ial_idme_highest { ['classic_loa3'] }
    va_eauth_csponly { ['true'] }
    va_eauth_authenticationMethod { ['multifactor'] }
    va_eauth_aal { ['2'] }
    va_eauth_emailaddress { ['vets.gov.user+262@example.com'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_authncontextclassref { ['multifactor'] }
    va_eauth_uid { ['54e78de6140d473f87960f211be49c08'] }
    va_eauth_issueinstant { ['2020-02-05T21:14:20Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_idme_loa3, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { LOA::IDME_LOA3 }
    end
    va_eauth_lastname { ['GPKTESTNINE'] }
    va_eauth_aal_idme_highest { ['2'] }
    va_eauth_aal { ['2'] }
    va_eauth_csid { ['idme'] }
    va_eauth_credentialassurancelevel { ['3'] }
    va_eauth_ial { ['3'] }
    va_eauth_ial_idme_highest { ['classic_loa3'] }
    va_eauth_firstname { ['JERRY'] }
    va_eauth_csponly { ['false'] }
    va_eauth_authenticationMethod { ['http://idmanagement.gov/ns/assurance/loa/3'] }
    va_eauth_emailaddress { ['vets.gov.user+262@example.com'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_authncontextclassref { ['http://idmanagement.gov/ns/assurance/loa/3'] }
    va_eauth_uid { ['54e78de6140d473f87960f211be49c08'] }
    va_eauth_issueinstant { ['2020-02-05T21:15:14Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }

    va_eauth_phone { ['(123)456-7890'] }
    va_eauth_street { ['999 Pizza Place'] }
    va_eauth_street1 { ['NOT_FOUND'] }
    va_eauth_street2 { ['NOT_FOUND'] }
    va_eauth_street3 { ['NOT_FOUND'] }
    va_eauth_city { ['Dallas'] }
    va_eauth_state { ['TX'] }
    va_eauth_postalcode { ['77665'] }
    va_eauth_country { ['NOT_FOUND'] }

    va_eauth_prefix { ['NOT_FOUND'] }
    va_eauth_suffix { ['NOT_FOUND'] }

    va_eauth_icn { ['1008830476V316605'] }
    va_eauth_csp_identifier { ['200VIDM'] }
    va_eauth_gender { ['male'] }
    va_eauth_csp_method { ['IDME'] }
    va_eauth_dodedipnid { ['NOT_FOUND'] }
    va_eauth_cspid { ['200VIDM_54e78de6140d473f87960f211be49c08'] }
    va_eauth_birthDate_v1 { ['19690407'] }
    va_eauth_birlsfilenumber { ['NOT_FOUND'] }
    va_eauth_proofingAuthority { ['FICAM'] }
    va_eauth_pid { ['NOT_FOUND'] }
    va_eauth_pnidtype { ['SSN'] }
    va_eauth_mcid { ['WSSOE2002051615154200356008529'] }
    va_eauth_pnid { ['666271152'] }
    va_eauth_commonname { ['vets.gov.user+262@example.com'] }
    va_eauth_isDelegate { ['false'] }
    va_eauth_secid { ['1008830476'] }
    va_eauth_gcIds {
      ['1008830476V316605^NI^200M^USVHA^P|' \
       '54e78de6140d473f87960f211be49c08^PN^200VIDM^USDVA^A|' \
       '1008830476^PN^200PROV^USDVA^A|123456^PI^200CRNR^USVHA^A|' \
       '123456^PI^200MHV^USVHA^C']
    }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_mhv_ien { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # Federated SSOe-ID.me user with MHV basic credential
  # for a user who has never been identity proofed
  factory :ssoe_idme_mhv_basic_neverproofed, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'myhealthevet' }
    end
    va_eauth_csid { ['idme'] }
    va_eauth_lastname { ['NOT_FOUND'] }
    va_eauth_credentialassurancelevel { ['1'] }
    va_eauth_aal_idme_highest { ['2'] }
    va_eauth_ial_idme_highest { ['1'] }
    va_eauth_ial { ['1'] }
    va_eauth_firstname { ['NOT_FOUND'] }
    va_eauth_csponly { ['true'] }
    va_eauth_authenticationMethod { ['myhealthevet'] }
    va_eauth_aal { ['2'] }
    va_eauth_emailaddress { ['pv+mhvtest1@example.com'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_authncontextclassref { ['myhealthevet'] }
    va_eauth_uid { ['72782a87a807407f83e8a052d804d7f7'] }
    va_eauth_issueinstant { ['2020-02-26T04:07:03Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_mhvassurance { ['Basic'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # Federated SSOe-ID.me user with MHV basic credential
  # for a user who has not enrolled in 2FA
  factory :ssoe_idme_mhv_basic_singlefactor, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'myhealthevet' }
    end
    va_eauth_csid { ['idme'] }
    va_eauth_lastname { ['NOT_FOUND'] }
    va_eauth_credentialassurancelevel { ['1'] }
    # TODO: this assertion is currently missing these two attribute
    # va_eauth_aal_idme_highest { ['1'] }
    # va_eauth_aal { ['1'] }
    va_eauth_ial_idme_highest { ['1'] }
    va_eauth_ial { ['1'] }
    va_eauth_firstname { ['NOT_FOUND'] }
    va_eauth_csponly { ['true'] }
    va_eauth_authenticationMethod { ['myhealthevet'] }
    va_eauth_emailaddress { ['pv+mhvtestb@example.com'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_authncontextclassref { ['myhealthevet'] }
    va_eauth_uid { ['72782a87a807407f83e8a052d804d7f7'] }
    va_eauth_issueinstant { ['2020-02-26T04:07:03Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_multifactor { ['false'] }
    va_eauth_mhvassurance { ['Basic'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # Federated SSOe-ID.me user with MHV basic credential
  # for a user who is adding multifactor
  factory :ssoe_idme_mhv_basic_multifactor, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'myhealthevet_multifactor' }
    end
    va_eauth_csid { ['idme'] }
    va_eauth_lastname { ['NOT_FOUND'] }
    va_eauth_credentialassurancelevel { ['1'] }
    va_eauth_aal_idme_highest { ['2'] }
    va_eauth_aal { ['2'] }
    va_eauth_ial_idme_highest { ['1'] }
    va_eauth_ial { ['1'] }
    va_eauth_firstname { ['NOT_FOUND'] }
    va_eauth_csponly { ['true'] }
    va_eauth_authenticationMethod { ['myhealthevet_multifactor'] }
    va_eauth_emailaddress { ['pv+mhvtestb@example.com'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_authncontextclassref { ['myhealthevet_multifactor'] }
    va_eauth_uid { ['72782a87a807407f83e8a052d804d7f7'] }
    va_eauth_issueinstant { ['2020-02-26T04:07:03Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_mhvassurance { ['Basic'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # Federated SSOe-ID.me user with MHV basic credential
  # Note this user has previously been verified but this
  # SAML attribute set represents the initial non-verified request
  factory :ssoe_idme_mhv_advanced, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'myhealthevet' }
    end
    va_eauth_csid { ['idme'] }
    va_eauth_lastname { ['NOT_FOUND'] }
    va_eauth_aal_idme_highest { ['2'] }
    va_eauth_credentialassurancelevel { ['1'] }
    va_eauth_ial { ['1'] }
    va_eauth_firstname { ['NOT_FOUND'] }
    va_eauth_ial_idme_highest { ['classic_loa3'] }
    va_eauth_csponly { ['true'] }
    va_eauth_authenticationMethod { ['myhealthevet'] }
    va_eauth_aal { ['2'] }
    va_eauth_emailaddress { ['alexmac_0@example.com'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_authncontextclassref { ['myhealthevet'] }
    va_eauth_uid { ['881571066e5741439652bc80759dd88c'] }
    va_eauth_issueinstant { ['2020-02-25T01:37:51Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_mhvassurance { ['Advanced'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # Federated SSOe-ID.me user with MHV advanced credential who
  # has been verified through ID.me
  factory :ssoe_idme_mhv_loa3, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'myhealthevet_loa3' }
    end
    va_eauth_phone { ['NOT_FOUND'] }
    va_eauth_lastname { ['MAC'] }
    va_eauth_ial { ['3'] }
    va_eauth_ial_idme_highest { ['classic_loa3'] }
    va_eauth_icn { ['1013183292V131165'] }
    va_eauth_city { ['Washington'] }
    va_eauth_country { ['USA'] }
    va_eauth_csp_identifier { ['200VIDM'] }
    va_eauth_gender { ['female'] }
    va_eauth_street2 { ['NOT_FOUND'] }
    va_eauth_aal { ['2'] }
    va_eauth_aal_idme_highest { ['2'] }
    va_eauth_csp_method { ['IDME_MHV'] }
    va_eauth_dodedipnid { ['NOT_FOUND'] }
    va_eauth_emailaddress { ['alexmac_0@example.com'] }
    va_eauth_cspid { ['200VIDM_881571066e5741439652bc80759dd88c'] }
    va_eauth_authncontextclassref { ['myhealthevet_loa3'] }
    va_eauth_issueinstant { ['2020-02-25T01:37:57Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_birthDate_v1 { ['19881124'] }
    va_eauth_state { ['DC'] }
    va_eauth_birlsfilenumber { ['NOT_FOUND'] }
    va_eauth_postalcode { ['20571-0001'] }
    va_eauth_mhvassurance { ['Advanced'] }
    va_eauth_street3 { ['NOT_FOUND'] }
    va_eauth_csid { ['idme'] }
    va_eauth_proofingAuthority { ['MHV'] }
    va_eauth_pid { ['NOT_FOUND'] }
    va_eauth_credentialassurancelevel { ['3'] }
    va_eauth_pnidtype { ['SSN'] }
    va_eauth_mcid { ['WSSOE2002242037576871098176537'] }
    va_eauth_firstname { ['ALEX'] }
    va_eauth_mhvprofile { ['{"accountType":"Basic","availableServices":{"1":"Blue Button self entered data."}}'] }
    va_eauth_prefix { ['NOT_FOUND'] }
    va_eauth_street { ['811 Vermont Ave NW'] }
    va_eauth_csponly { ['false'] }
    va_eauth_pnid { ['230595111'] }
    va_eauth_commonname { ['alexmac_0@example.com'] }
    va_eauth_authenticationMethod { ['myhealthevet_loa3'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_mhvuuid { ['15001594'] }
    va_eauth_suffix { ['NOT_FOUND'] }
    va_eauth_uid { ['881571066e5741439652bc80759dd88c'] }
    va_eauth_isDelegate { ['false'] }
    va_eauth_secid { ['1013183292'] }
    va_eauth_gcIds {
      ['1013183292V131165^NI^200M^USVHA^P|' \
       '1013183292^PN^200PROV^USDVA^A|' \
       '881571066e5741439652bc80759dd88c^PN^200VIDM^USDVA^A|' \
       '15001594^PI^200MHS^USVHA^A']
    }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_street1 { ['NOT_FOUND'] }
    va_eauth_mhv_ien { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # Federated SSOe-ID.me user with MHV premium credential
  factory :ssoe_idme_mhv_premium, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'myhealthevet' }
    end
    va_eauth_icn { ['1012853550V207686'] }
    va_eauth_cspid { ['200VIDM_0e1bb5723d7c4f0686f46ca4505642ad'] }
    va_eauth_birthDate_v1 { ['19770307'] }
    va_eauth_state { ['KY'] }
    va_eauth_postalcode { ['56473'] }
    va_eauth_csid { ['idme'] }
    va_eauth_pid { ['NOT_FOUND'] }
    va_eauth_pnidtype { ['SSN'] }
    va_eauth_firstname { ['TRISTAN'] }
    va_eauth_mhvprofile {
      ['{"accountType":"Premium","availableServices":{"21":"VA Medications",' \
       '"4":"Secure Messaging","3":"VA Allergies","2":"Rx Refill",' \
       '"12":"Blue Button (all VA data)","1":"Blue Button self entered data.",' \
       '"11":"Blue Button (DoD) Military Service Information"}}']
    }
    va_eauth_street { ['954 Bourbon Way'] }
    va_eauth_authenticationMethod { ['myhealthevet'] }
    va_eauth_uid { ['0e1bb5723d7c4f0686f46ca4505642ad'] }
    va_eauth_isDelegate { ['false'] }
    va_eauth_secid { ['1012853550'] }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_street1 { ['NOT_FOUND'] }
    va_eauth_phone { ['NOT_FOUND'] }
    va_eauth_lastname { ['GPTESTSYSTWO'] }
    va_eauth_ial_idme_highest { ['classic_loa3'] }
    va_eauth_ial { ['3'] }
    va_eauth_city { ['Lexington'] }
    va_eauth_country { ['USA'] }
    va_eauth_csp_identifier { ['200VIDM'] }
    va_eauth_gender { ['MALE'] }
    va_eauth_street2 { ['NOT_FOUND'] }
    va_eauth_aal_idme_highest { ['2'] }
    va_eauth_aal { ['2'] }
    va_eauth_csp_method { ['IDME_MHV'] }
    va_eauth_dodedipnid { ['2107307560'] }
    va_eauth_emailaddress { ['k+tristanmhv@example.com'] }
    va_eauth_authncontextclassref { ['myhealthevet'] }
    va_eauth_issueinstant { ['2020-02-26T04:23:31Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_birlsfilenumber { ['NOT_FOUND'] }
    va_eauth_mhvassurance { ['Premium'] }
    va_eaauth_mhvicn { ['1012853550V207686'] }
    va_eauth_street3 { ['NOT_FOUND'] }
    va_eauth_proofingAuthority { ['MHV'] }
    va_eauth_credentialassurancelevel { ['3'] }
    va_eauth_mcid { ['WSSOE2002252323315192027814298'] }
    va_eauth_prefix { ['NOT_FOUND'] }
    va_eauth_csponly { ['false'] }
    va_eauth_pnid { ['666811850'] }
    va_eauth_commonname { ['k+tristan@example.com'] }
    va_eauth_transactionid { ['VDeAfteF14dJV9gke1tQ4rBX2UntryiGMkD5anKJiHQ='] }
    va_eauth_mhvuuid { ['12345748'] }
    va_eauth_suffix { ['NOT_FOUND'] }
    va_eauth_gcIds {
      ['1012853550V207686^NI^200M^USVHA^P|' \
       '552151510^PI^989^USVHA^A|' \
       '943571^PI^979^USVHA^A|' \
       '12345748^PI^200MH^USVHA^A|' \
       '1012853550^PN^200PROV^USDVA^A|' \
       '7219295^PI^983^USVHA^A|' \
       '552161765^PI^984^USVHA^A|' \
       '2107307560^NI^200DOD^USDOD^A|' \
       '7b9b5861203244f0b99b02b771159044^PN^200VIDM^USDVA^A|' \
       '0e1bb5723d7c4f0686f46ca4505642ad^PN^200VIDM^USDVA^A|' \
       '12345748^PI^200MHS^USVHA^A']
    }
    va_eauth_mhv_ien { ['12345748'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # TODO: make this reflective of DSLogon 1 user
  factory :ssoe_idme_dslogon_level1, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'dslogon' }
    end
    va_eauth_csid { ['idme'] }
    va_eauth_lastname { ['GPKTESTNINE'] }
    va_eauth_credentialassurancelevel { ['3'] }
    va_eauth_ial { ['3'] }
    va_eauth_firstname { ['JERRY'] }
    va_eauth_csponly { ['false'] }
    va_eauth_authenticationMethod { ['http://idmanagement.gov/ns/assurance/loa/3'] }
    va_eauth_aal { ['2'] }
    va_eauth_emailaddress { ['vets.gov.user+262@example.com'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_authncontextclassref { ['http://idmanagement.gov/ns/assurance/loa/3'] }
    va_eauth_uid { ['54e78de6140d473f87960f211be49c08'] }
    va_eauth_issueinstant { ['2020-02-05T21:15:14Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }

    va_eauth_phone { ['NOT_FOUND'] }
    va_eauth_street { ['NOT_FOUND'] }
    va_eauth_street1 { ['NOT_FOUND'] }
    va_eauth_street2 { ['NOT_FOUND'] }
    va_eauth_street3 { ['NOT_FOUND'] }
    va_eauth_city { ['NOT_FOUND'] }
    va_eauth_state { ['NOT_FOUND'] }
    va_eauth_postalcode { ['NOT_FOUND'] }
    va_eauth_country { ['NOT_FOUND'] }

    va_eauth_prefix { ['NOT_FOUND'] }
    va_eauth_suffix { ['NOT_FOUND'] }

    va_eauth_icn { ['1008830476V316605'] }
    va_eauth_csp_identifier { ['200VIDM'] }
    va_eauth_gender { ['male'] }
    va_eauth_csp_method { ['IDME'] }
    va_eauth_dodedipnid { ['NOT_FOUND'] }
    va_eauth_cspid { ['200VIDM_54e78de6140d473f87960f211be49c08'] }
    va_eauth_birthDate_v1 { ['19690407'] }
    va_eauth_birlsfilenumber { ['NOT_FOUND'] }
    va_eauth_proofingAuthority { ['FICAM'] }
    va_eauth_pid { ['NOT_FOUND'] }
    va_eauth_pnidtype { ['SSN'] }
    va_eauth_mcid { ['WSSOE2002051615154200356008529'] }
    va_eauth_pnid { ['666271152'] }
    va_eauth_commonname { ['vets.gov.user+262@example.com'] }
    va_eauth_isDelegate { ['false'] }
    va_eauth_secid { ['1008830476'] }
    va_eauth_gcIds {
      ['1008830476V316605^NI^200M^USVHA^P|' \
       '54e78de6140d473f87960f211be49c08^PN^200VIDM^USDVA^A|' \
       '1008830476^PN^200PROV^USDVA^A']
    }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_mhv_ien { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_idme_dslogon_level2, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'dslogon' }
    end
    va_eauth_phone { ['(202)555-9320'] }
    va_eauth_lastname { ['WEAVER'] }
    va_eauth_ial { ['2'] }
    va_eauth_icn { ['1012740600V714187'] }
    va_eauth_city { ['Washington'] }
    va_eauth_country { ['USA'] }
    va_eauth_csp_identifier { ['200VIDM'] }
    va_eauth_gender { ['MALE'] }
    va_eauth_street2 { ['NOT_FOUND'] }
    va_eauth_aal { ['1'] }
    va_eauth_dslogonassurance { ['2'] }
    va_eauth_csp_method { ['IDME_DSL'] }
    va_eauth_dodedipnid { ['1005169255'] }
    va_eauth_emailaddress { ['Test0206@gmail.com'] }
    va_eauth_cspid { ['200VIDM_1655c16aa0784dbe973814c95bd69177'] }
    va_eauth_authncontextclassref { ['dslogon'] }
    va_eauth_dslogonuuid { ['1005169255'] }
    va_eauth_issueinstant { ['2020-02-24T23:21:41Z'] }
    va_eauth_middlename { ['LEONARD'] }
    va_eauth_birthDate_v1 { ['19560710'] }
    va_eauth_state { ['DC'] }
    va_eauth_birlsfilenumber { ['796123607'] }
    va_eauth_postalcode { ['20571-0001'] }
    va_eauth_street3 { ['NOT_FOUND'] }
    va_eauth_csid { ['idme'] }
    va_eauth_proofingAuthority { ['DMDC'] }
    va_eauth_pid { ['600043180'] }
    va_eauth_credentialassurancelevel { ['3'] }
    va_eauth_pnidtype { ['SSN'] }
    va_eauth_mcid { ['WSSOE2002241821433910863216572'] }
    va_eauth_firstname { ['JOHNNIE'] }
    va_eauth_prefix { ['NOT_FOUND'] }
    va_eauth_street { ['811 Vermont Ave NW'] }
    va_eauth_csponly { ['false'] }
    va_eauth_pnid { ['796123607'] }
    va_eauth_commonname { ['dslogon10923109@gmail.com'] }
    va_eauth_authenticationMethod { ['dslogon'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_suffix { ['NOT_FOUND'] }
    va_eauth_uid { ['1655c16aa0784dbe973814c95bd69177'] }
    va_eauth_isDelegate { ['false'] }
    va_eauth_secid { ['0000028007'] }
    va_eauth_gcIds {
      ['1012740600V714187^NI^200M^USVHA^P|' \
       '552151338^PI^989^USVHA^A|' \
       '1005169255^NI^200DOD^USDOD^A|' \
       '796123607^PI^200BRLS^USVBA^A|' \
       '600043180^PI^200CORP^USVBA^A|' \
       '0000028007^PN^200PROV^USDVA^A|' \
       '0000001012740600V714187000000^PI^200ESR^USVHA^A|' \
       '14384899^PI^200MHS^USVHA^A|' \
       '1133902^PI^200VETS^USDVA^A|' \
       '1655c16aa0784dbe973814c95bd69177^PN^200VIDM^USDVA^A|' \
       '1306e31273604dd4a12aa67609a63bfe^PN^200VIDM^USDVA^A|' \
       '796123607^AN^200CORP^USVBA^']
    }
    va_eauth_persontype { ['PAT|VET'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_street1 { ['811 Vermont Ave NW'] }
    va_eauth_mhv_ien { ['14384899'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_idme_dslogon_level2_singlefactor, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'dslogon' }
    end
    va_eauth_aal_idme_highest { ['1'] }
    va_eauth_icn { ['1013173963V366678'] }
    va_eauth_ial_idme_highest { ['1'] }
    va_eauth_dslogonassurance { ['2'] }
    va_eauth_cspid { ['200VIDM_363761e8857642f7b77ef7d99200e711'] }
    va_eauth_birthDate_v1 { ['19510604'] }
    va_eauth_state { ['NOT_FOUND'] }
    va_eauth_postalcode { ['NOT_FOUND'] }
    va_eauth_csid { ['idme'] }
    va_eauth_pid { ['NOT_FOUND'] }
    va_eauth_pnidtype { ['SSN'] }
    va_eauth_firstname { ['BRANDIN'] }
    va_eauth_street { ['NOT_FOUND'] }
    va_eauth_authenticationMethod { ['dslogon'] }
    va_eauth_uid { ['363761e8857642f7b77ef7d99200e711'] }
    va_eauth_isDelegate { ['false'] }
    va_eauth_secid { ['1013173963'] }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_multifactor { ['false'] }
    va_eauth_street1 { ['NOT_FOUND'] }
    va_eauth_phone { ['NOT_FOUND'] }
    va_eauth_lastname { ['MILLER-NIETO'] }
    va_eauth_ial { ['2'] }
    va_eauth_city { ['NOT_FOUND'] }
    va_eauth_country { ['NOT_FOUND'] }
    va_eauth_csp_identifier { ['200VIDM'] }
    va_eauth_gender { ['MALE'] }
    va_eauth_street2 { ['NOT_FOUND'] }
    va_eauth_aal { ['1'] }
    va_eauth_csp_method { ['IDME_DSL'] }
    va_eauth_dodedipnid { ['2106798217'] }
    va_eauth_emailaddress { ['iam.tester@example.com'] }
    va_eauth_authncontextclassref { ['dslogon'] }
    va_eauth_dslogonuuid { ['2106798217'] }
    va_eauth_issueinstant { ['2020-03-18T00:05:57Z'] }
    va_eauth_middlename { ['BRANSON'] }
    va_eauth_birlsfilenumber { ['NOT_FOUND'] }
    va_eauth_street3 { ['NOT_FOUND'] }
    va_eauth_proofingAuthority { ['DMDC'] }
    va_eauth_credentialassurancelevel { ['2'] }
    va_eauth_mcid { ['WSSOE2003172005598450418218420'] }
    va_eauth_prefix { ['NOT_FOUND'] }
    va_eauth_csponly { ['false'] }
    va_eauth_pnid { ['666016789'] }
    va_eauth_commonname { ['iam.tester@example.com'] }
    va_eauth_transactionid { ['3oiTInhBKGiA/FbtYGVloGdOqUtvKCw4rcuchfwPNAo='] }
    va_eauth_suffix { ['NOT_FOUND'] }
    va_eauth_gcIds {
      ['1013173963V366678^NI^200M^USVHA^P|' \
       '363761e8857642f7b77ef7d99200e711^PN^200VIDM^USDVA^A|' \
       '2106798217^NI^200DOD^USDOD^A|' \
       '1013173963^PN^200PROV^USDVA^A']
    }
    va_eauth_mhv_ien { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_inbound_dslogon_level2, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'urn:oasis:names:tc:SAML:2.0:ac:classes:Password' }
    end
    va_eauth_phone { ['(555)555-5555'] }
    va_eauth_lastname { ['MCKIBBENS'] }
    va_eauth_icn { ['1012779219V964737'] }
    va_eauth_city { ['CHEYENNE'] }
    va_eauth_sponsorDodEdiPnId { ['1606997570'] }
    va_eauth_country { ['USA'] }
    va_eauth_csp_identifier { ['200DOD'] }
    va_eauth_gender { ['FEMALE'] }
    va_eauth_street2 { ['NOT_FOUND'] }
    va_eauth_csp_method { ['DSL'] }
    va_eauth_dodedipnid { ['1606997570'] }
    va_eauth_emailaddress { ['NOT_FOUND'] }
    va_eauth_cspid { ['200DOD_1606997570'] }
    va_eauth_issueinstant { ['2020-03-20T20:45:12Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_birthDate_v1 { ['19461020'] }
    va_eauth_state { ['WY'] }
    va_eauth_birlsfilenumber { ['NOT_FOUND'] }
    va_eauth_authorization {
      ['{"authorizationResponse":{"id":"101174874",' \
       '"idType":"SSN","lastName":"MCKIBBENS","firstName":"SOFIA",' \
       '"middleName":"","cadencyName":"","deceased":false,' \
       '"birthDate":"1946-10-20T08:00:00Z","gender":"FEMALE",' \
       '"edi":1606997570,"benefits":[],"personnels":[],' \
       '"status":"VETERAN","personAssociatedSet":[]}}']
    }
    va_eauth_postalcode { ['82009'] }
    va_eauth_authenticationAuthority { ['D'] }
    va_eauth_street3 { ['NOT_FOUND'] }
    va_eauth_csid { ['DSLogon'] }
    va_eauth_proofingAuthority { ['DMDC'] }
    va_eauth_pid { ['NOT_FOUND'] }
    va_eauth_credentialassurancelevel { ['2'] }
    va_eauth_pnidtype { ['SSN'] }
    va_eauth_mcid { ['WSSOE2003201645189620771963396'] }
    va_eauth_firstname { ['SOFIA'] }
    va_eauth_prefix { ['NOT_FOUND'] }
    va_eauth_street { ['6021 WEAVER RD'] }
    va_eauth_csponly { ['false'] }
    va_eauth_pnid { ['101174874'] }
    va_eauth_commonname { ['SOFIA MCKIBBENS'] }
    va_eauth_authenticationMethod { ['DSLogon'] }
    va_eauth_transactionid { ['yGXMk81W0r3aArfVXHdZuCl5utlNQ1adITH8QHsLlB0'] }
    va_eauth_suffix { ['NOT_FOUND'] }
    va_eauth_uid { ['id=sofia.mckibbens,ou=user,ou=People,o=Beneficiaries,dc=osd,dc=mil'] }
    va_eauth_isDelegate { ['false'] }
    va_eauth_secid { ['1012779219'] }
    va_eauth_gcIds {
      ['1012779219V964737^NI^200M^USVHA^P|' \
       '38401^PI^451^USVHA^A|' \
       '1606997570^NI^200DOD^USDOD^A|' \
       '38401^PI^969^USVHA^A|' \
       '1012779219^PN^200PROV^USDVA^A']
    }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_street1 { ['6021 WEAVER RD'] }
    va_eauth_mhvien { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_inbound_mhv_premium, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { 'urn:oasis:names:tc:SAML:2.0:ac:classes:Password' }
    end
    va_eauth_phone { ['NOT_FOUND'] }
    va_eauth_lastname { ['DAYTMHV'] }
    va_eauth_icn { ['1013062086V794840'] }
    va_eauth_city { ['NOT_FOUND'] }
    va_eauth_country { ['NOT_FOUND'] }
    va_eauth_csp_identifier { ['200MH'] }
    va_eauth_gender { ['MALE'] }
    va_eauth_street2 { ['NOT_FOUND'] }
    va_eauth_csp_method { ['MHV'] }
    va_eauth_dodedipnid { ['NOT_FOUND'] }
    va_eauth_emailaddress { ['NOT_FOUND'] }
    va_eauth_cspid { ['200MH_15093546'] }
    va_eauth_issueinstant { ['2020-03-20T20:36:19Z'] }
    va_eauth_birthDate_v1 { ['19820523'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_state { ['NOT_FOUND'] }
    va_eauth_birlsfilenumber { ['NOT_FOUND'] }
    va_eauth_postalcode { ['NOT_FOUND'] }
    va_eauth_street3 { ['NOT_FOUND'] }
    va_eauth_proofingAuthority { ['FICAM'] }
    va_eauth_pid { ['NOT_FOUND'] }
    va_eauth_csid { ['mhv'] }
    va_eauth_credentialassurancelevel { ['2'] }
    va_eauth_pnidtype { ['SSN'] }
    va_eauth_mcid { ['WSSOE2003201636186742109041579'] }
    va_eauth_firstname { ['ZACK'] }
    va_eauth_prefix { ['NOT_FOUND'] }
    va_eauth_street { ['NOT_FOUND'] }
    va_eauth_csponly { ['false'] }
    va_eauth_pnid { ['666872589'] }
    va_eauth_commonname { ['mhvzack@mhv.va.gov'] }
    va_eauth_authenticationMethod { ['urn:oasis:names:tc:SAML:2.0:ac:classes:unspecified'] }
    va_eauth_transactionid { ['6e/7qHvlmQR0NPaplboby1mJJlKDKz2UEXk9Ul9e5tU='] }
    va_eauth_suffix { ['NOT_FOUND'] }
    va_eauth_uid { ['15093546'] }
    va_eauth_isDelegate { ['false'] }
    va_eauth_secid { ['1013062086'] }
    va_eauth_gcIds {
      ['1013062086V794840^NI^200M^USVHA^P|' \
       '15093546^PI^200MHS^USVHA^A|' \
       '552151869^PI^989^USVHA^A|' \
       '18277^PI^200VETS^USDVA^A|' \
       '1013062086^PN^200PROV^USDVA^A|' \
       '15093546^PI^200MH^USVHA^A|' \
       '53f065475a794e14a32d707bfd9b215f^PN^200VIDM^USDVA^A']
    }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_street1 { ['NOT_FOUND'] }
    va_eauth_mhvien { ['15093546'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_inbound_idme_loa3, class: 'OneLogin::RubySaml::Attributes' do
    transient do
      authn_context { LOA::IDME_LOA3 }
    end
    va_eauth_phone { ['(111)111-1111'] }
    va_eauth_lastname { ['GPKTESTNINE'] }
    va_eauth_aal_idme_highest { ['2'] }
    va_eauth_ial { ['3'] }
    va_eauth_icn { ['1012827134V054550'] }
    va_eauth_city { ['New York'] }
    va_eauth_ial_idme_highest { ['classic_loa3'] }
    va_eauth_country { ['USA'] }
    va_eauth_csp_identifier { ['200VIDM'] }
    va_eauth_gender { ['MALE'] }
    va_eauth_street2 { ['NOT_FOUND'] }
    va_eauth_aal { ['2'] }
    va_eauth_csp_method { ['IDME'] }
    va_eauth_dodedipnid { ['1320002060'] }
    va_eauth_emailaddress { ['vets.gov.user+262@gmail.com'] }
    va_eauth_cspid { ['200VIDM_54e78de6140d473f87960f211be49c08'] }
    va_eauth_authncontextclassref { ['http://idmanagement.gov/ns/assurance/loa/3'] }
    va_eauth_issueinstant { ['2020-03-20T20:50:12Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_birthDate_v1 { ['19690407'] }
    va_eauth_state { ['NY'] }
    va_eauth_birlsfilenumber { ['666271151'] }
    va_eauth_postalcode { ['10036'] }
    va_eauth_street3 { ['NOT_FOUND'] }
    va_eauth_csid { ['idme'] }
    va_eauth_proofingAuthority { ['FICAM'] }
    va_eauth_pid { ['600152411'] }
    va_eauth_credentialassurancelevel { ['3'] }
    va_eauth_pnidtype { ['SSN'] }
    va_eauth_mcid { ['WSSOE2003201650138851548832059'] }
    va_eauth_firstname { ['JERRY'] }
    va_eauth_prefix { ['NOT_FOUND'] }
    va_eauth_street { ['567 W 42nd St'] }
    va_eauth_csponly { ['false'] }
    va_eauth_pnid { ['666271152'] }
    va_eauth_commonname { ['vets.gov.user+262@gmail.com'] }
    va_eauth_authenticationMethod { ['http://idmanagement.gov/ns/assurance/loa/3'] }
    va_eauth_transactionid { ['HZmR3a1TZAnLNzLfliYLFXO6Xu1cUEA1p18v2B3bekI='] }
    va_eauth_suffix { ['NOT_FOUND'] }
    va_eauth_uid { ['54e78de6140d473f87960f211be49c08'] }
    va_eauth_isDelegate { ['false'] }
    va_eauth_secid { ['1012827134'] }
    va_eauth_gcIds {
      ['1012827134V054550^NI^200M^USVHA^P|' \
       '10894456^PI^200MHS^USVHA^A|' \
       '943523^PI^979^USVHA^A|' \
       '552151501^PI^989^USVHA^A|' \
       '666271151^PI^200BRLS^USVBA^A|' \
       '1320002060^NI^200DOD^USDOD^A|' \
       '20381^PI^200VETS^USDVA^A|' \
       'aa478abc-e494-4ae1-8f87-d002f8fe1bbd^PN^200VLGN^USDVA^A|' \
       '54e78de6140d473f87960f211be49c08^PN^200VIDM^USDVA^A|' \
       '1012827134^PN^200PROV^USDVA^A|' \
       '600152411^PI^200CORP^USVBA^A']
    }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_street1 { ['NOT_FOUND'] }
    va_eauth_mhvien { ['10894456'] }

    initialize_with { new(attributes.stringify_keys) }
  end
end
