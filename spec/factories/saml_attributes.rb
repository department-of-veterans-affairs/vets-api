# frozen_string_literal: true

FactoryBot.define do
  factory :idme_loa1, class: OneLogin::RubySaml::Attributes do
    transient do
      authn_context { 'http://idmanagement.gov/ns/assurance/loa/1/vets' }
    end
    uuid { ['0e1bb5723d7c4f0686f46ca4505642ad'] }
    email { ['kam+tristanmhv@adhocteam.us'] }
    multifactor { [false] }
    level_of_assurance { ['1'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :idme_loa3, class: OneLogin::RubySaml::Attributes do
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

  factory :mhv_basic, class: OneLogin::RubySaml::Attributes do
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

  factory :mhv_advanced, class: OneLogin::RubySaml::Attributes do
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

  factory :mhv_premium, class: OneLogin::RubySaml::Attributes do
    transient do
      authn_context { 'myhealthevet' }
    end
    mhv_icn { ['1012853550V207686'] }
    mhv_profile {
      [
        '{"accountType":"Premium","availableServices":{"21":"VA Medications",'\
        '"4":"Secure Messaging","3":"VA Allergies","2":"Rx Refill",'\
        '"12":"Blue Button (all VA data)","1":"Blue Button self entered data.",'\
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
  factory :mhv_loa3, class: OneLogin::RubySaml::Attributes do
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

  factory :dslogon_level1, class: OneLogin::RubySaml::Attributes do
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

  factory :dslogon_level2, class: OneLogin::RubySaml::Attributes do
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

  factory :ssoe_unmappable_response, class: OneLogin::RubySaml::Attributes do
    iam_eai_auth_level { ['[Filtered]'] }
    am_eai_ext_user_groups { ['[Filtered]'] }
    am_eai_ext_user_id { ['[Filtered]'] }
    am_eai_fim_xattrs { ['mapper_error,jstrackinguuid'] }
    jstrackinguuid { ['Track-Yw4ggABCFl'] }
    mapper_error { ['PRINCIPAL SEC_ID is NULL/EMPTY OR NOT FOUND for VA gov (vagov)'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_idme_loa1, class: OneLogin::RubySaml::Attributes do
    transient do
      authn_context { LOA::IDME_LOA1_VETS }
    end
    va_eauth_csid { ['idme'] }
    va_eauth_lastname { ['GPKTESTNINE'] }
    va_eauth_credentialassurancelevel { ['1'] }
    va_eauth_ial { ['1'] }
    va_eauth_firstname { ['JERRY'] }
    va_eauth_csponly { ['true'] }
    va_eauth_authenticationMethod { ['http://idmanagement.gov/ns/assurance/loa/1/vets'] }
    va_eauth_aal { ['1'] }
    va_eauth_emailaddress { ['vets.gov.user+262@example.com'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_authncontextclassref { ['http://idmanagement.gov/ns/assurance/loa/1/vets'] }
    va_eauth_uid { ['54e78de6140d473f87960f211be49c08'] }
    va_eauth_issueinstant { ['2020-02-05T21:14:20Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_idme_loa3, class: OneLogin::RubySaml::Attributes do
    transient do
      authn_context { LOA::IDME_LOA3 }
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
      ['1008830476V316605^NI^200M^USVHA^P|'\
       '54e78de6140d473f87960f211be49c08^PN^200VIDM^USDVA^A|'\
       '1008830476^PN^200PROV^USDVA^A']
    }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_mhv_ien { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # TODO: make this reflective of MHV basic user
  factory :ssoe_idme_mhv_basic, class: OneLogin::RubySaml::Attributes do
    transient do
      authn_context { 'myhealthevet' }
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
      ['1008830476V316605^NI^200M^USVHA^P|'\
       '54e78de6140d473f87960f211be49c08^PN^200VIDM^USDVA^A|'\
       '1008830476^PN^200PROV^USDVA^A']
    }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_mhv_ien { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # TODO: make this reflective of MHV premium user
  factory :ssoe_idme_mhv_premium, class: OneLogin::RubySaml::Attributes do
    transient do
      authn_context { 'myhealthevet' }
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
      ['1008830476V316605^NI^200M^USVHA^P|'\
       '54e78de6140d473f87960f211be49c08^PN^200VIDM^USDVA^A|'\
       '1008830476^PN^200PROV^USDVA^A']
    }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_mhv_ien { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # TODO: make this reflective of DSLogon 1 user
  factory :ssoe_idme_dslogon_level1, class: OneLogin::RubySaml::Attributes do
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
      ['1008830476V316605^NI^200M^USVHA^P|'\
       '54e78de6140d473f87960f211be49c08^PN^200VIDM^USDVA^A|'\
       '1008830476^PN^200PROV^USDVA^A']
    }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_mhv_ien { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # TODO: make this reflective of DSLogon 2 user
  factory :ssoe_idme_dslogon_level2, class: OneLogin::RubySaml::Attributes do
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
      ['1008830476V316605^NI^200M^USVHA^P|'\
       '54e78de6140d473f87960f211be49c08^PN^200VIDM^USDVA^A|'\
       '1008830476^PN^200PROV^USDVA^A']
    }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_mhv_ien { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end
end
