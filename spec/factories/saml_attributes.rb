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

  factory :ssoe_idme_loa1_unproofed, class: OneLogin::RubySaml::Attributes do
    transient do
      authn_context { LOA::IDME_LOA1_VETS }
    end
    va_eauth_csid { ['idme'] }
    va_eauth_emailaddress { ['vets.gov.user+262@example.com'] }
    va_eauth_lastname { ['GPKTESTNINE'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_authncontextclassref { ['http://idmanagement.gov/ns/assurance/loa/1/vets'] }
    va_eauth_credentialassurancelevel { ['1'] }
    va_eauth_uid { ['54e78de6140d473f87960f211be49c08'] }
    va_eauth_issueinstant { ['2020-02-05T21:14:20Z'] }
    va_eauth_firstname { ['JERRY'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_csponly { ['true'] }
    va_eauth_authenticationMethod { ['http://idmanagement.gov/ns/assurance/loa/1/vets'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  factory :ssoe_idme_loa1, class: OneLogin::RubySaml::Attributes do
    transient do
      authn_context { LOA::IDME_LOA1_VETS }
    end
    va_eauth_csid { ['idme'] }
    va_eauth_lastname { ['GPKTESTNINE'] }
    va_eauth_credentialassurancelevel { ['1'] }
    va_eauth_ial { ['3'] }
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

  # Federated SSOe-ID.me user with MHV basic credential
  # Note this user has previously been verified but this 
  # SAML attribute set represents the initial non-verified request
   factory :ssoe_idme_mhv_basic, class: OneLogin::RubySaml::Attributes do
    transient do
      authn_context { 'myhealthevet' }
    end
    va_eauth_csid { ['idme'] }
    va_eauth_lastname { ['NOT_FOUND'] }
    va_eauth_credentialassurancelevel { ['1'] }
    va_eauth_ial { ['1'] }
    va_eauth_firstname { ['NOT_FOUND'] }
    va_eauth_csponly { ['true'] }
    va_eauth_authenticationMethod { ['myhealthevet'] }
    va_eauth_aal { ['1'] }
    va_eauth_emailaddress { ['alexmac_0@example.com'] }
    va_eauth_transactionid { ['abcd1234xyz'] }
    va_eauth_authncontextclassref { ['myhealthevet'] }
    va_eauth_uid { ['881571066e5741439652bc80759dd88c'] }
    va_eauth_issueinstant { ['2020-02-25T01:37:51Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }

    initialize_with { new(attributes.stringify_keys) }
  end

  # Federated SSOe-ID.me user with MHV basic credential who
  # has been verified through ID.me
  factory :ssoe_idme_mhv_loa3, class: OneLogin::RubySaml::Attributes do
    transient do
      authn_context { 'myhealthevet_loa3' }
    end
    va_eauth_phone { ['NOT_FOUND'] }
    va_eauth_lastname { ['MAC'] }
    va_eauth_ial { ['3'] }
    va_eauth_icn { ['1013183292V131165'] }
    va_eauth_city { ['NOT_FOUND'] }
    va_eauth_country { ['NOT_FOUND'] }
    va_eauth_csp_identifier { ['200VIDM'] }
    va_eauth_gender { ['female'] }
    va_eauth_street2 { ['NOT_FOUND'] }
    va_eauth_aal { ['2'] }
    # va_eauth_dslogonassurance { ['2'] } not present for MHV
    va_eauth_csp_method { ['IDME_MHV'] }
    va_eauth_dodedipnid { ['NOT_FOUND'] }
    va_eauth_emailaddress { ['alexmac_0@example.com'] }
    va_eauth_cspid { ['200VIDM_881571066e5741439652bc80759dd88c'] }
    va_eauth_authncontextclassref { ['myhealthevet_loa3'] }
    # va_eauth_dslogonuuid { ['1005169255'] } not present for MHV
    va_eauth_issueinstant { ['2020-02-25T01:37:57Z'] }
    va_eauth_middlename { ['NOT_FOUND'] }
    va_eauth_birthDate_v1 { ['19881124'] }
    va_eauth_state { ['NOT_FOUND'] }
    va_eauth_birlsfilenumber { ['NOT_FOUND'] }
    va_eauth_postalcode { ['NOT_FOUND'] }
    va_eauth_mhvassurance { ['Basic'] }
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
      ['1013183292V131165^NI^200M^USVHA^P|'\
       '1013183292^PN^200PROV^USDVA^A|'\
       '881571066e5741439652bc80759dd88c^PN^200VIDM^USDVA^A']
    }
    va_eauth_persontype { ['NOT_FOUND'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_street1 { ['NOT_FOUND'] }
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

  factory :ssoe_idme_dslogon_level2, class: OneLogin::RubySaml::Attributes do
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
    va_eauth_credentialassurancelevel { ['2'] }
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
      ['1012740600V714187^NI^200M^USVHA^P|'\
       '552151338^PI^989^USVHA^A|'\
       '1005169255^NI^200DOD^USDOD^A|'\
       '796123607^PI^200BRLS^USVBA^A|'\
       '600043180^PI^200CORP^USVBA^A|'\
       '0000028007^PN^200PROV^USDVA^A|'\
       '0000001012740600V714187000000^PI^200ESR^USVHA^A|'\
       '14384899^PI^200MHS^USVHA^A|'\
       '1133902^PI^200VETS^USDVA^A|'\
       '1655c16aa0784dbe973814c95bd69177^PN^200VIDM^USDVA^A|'\
       '1306e31273604dd4a12aa67609a63bfe^PN^200VIDM^USDVA^A|'\
       '796123607^AN^200CORP^USVBA^']
    }
    va_eauth_persontype { ['PAT'] }
    va_eauth_multifactor { ['true'] }
    va_eauth_street1 { ['811 Vermont Ave NW'] }
    va_eauth_mhv_ien { ['14384899'] }
       
    initialize_with { new(attributes.stringify_keys) }
  end
end
