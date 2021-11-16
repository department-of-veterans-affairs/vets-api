# frozen_string_literal: true

FactoryBot.define do
  factory :dslogon_level2_introspection_payload, class: Hash do
    fediamtransaction_id { 'Yl5u1YecjH1qlWtGJxGjQtEJVpujROEotxY39gD2NTI=' }
    fediam_is_delegate { 'false' }
    fediam_birls_number { 'NOT_FOUND' }
    birthdate { '1970-08-12' }
    fediamss_issue_instant { '2021-02-12T17:42:40Z' }
    fediam_mviicn { '1012666182V203559' }
    fediam_street { '140 WHITEHAVEN CIR' }
    fediamsecid { '0000027792' }
    client_id { 'VAMobile' }
    fediam_country { 'USA' }
    fediam_gender { 'MALE' }
    exp { 1_613_153_567 }
    code_challenge { 'A0ZKRGWoD9TTNbO0j5mhDzV41jrLW-RbJZcAJsnjVTo' }
    fediam_street1 { '140 WHITEHAVEN CIR' }
    fediam_do_dedipn_id { '1005079124' }
    fediam_gc_id {
      '1012666182V203559^NI^200M^USVHA^P|7187659^PI^987^USVHA^A|0000001012666182V203559000000^PI^200ESR^USVHA^A|' \
        '0000001012666182V203559000000^PI^553^USVHA^A|600036159^PI^200CORP^USVBA^A|' \
        '1005079124^NI^200NDZ^2.16.840.1.113883.3.42.10001.100001.13^A|0000027792^PN^200PROV^USDVA^A|' \
        '14398876^PI^200MHS^USVHA^A|1005079124^NI^200DOD^USDOD^A|1411740^PI^200VETS^USDVA^A|' \
        '85c50aa76934460c8736f687a6a30546^PN^200VIDM^USDVA^A|796121200^AN^200CORP^USVBA^'
    }
    active { true }
    fediamauth_n_type { 'DSL' }
    fediamdmdc_authorization {
      '{"authorizationResponse":{"id":"796121200" }"idType":"SSN" }"lastName":"ANDERSON" }"firstName":"GREG" }' \
        '"middleName":"A" }"cadencyName":"" }"deceased":false,"birthDate":"1933-04-05T08:00:00Z" }"gender":"MALE" }' \
        '"edi":1005079124,"benefits":["21"],"personnels":[{"organization":"21" }"category":"RETIRED_MILITARY" }' \
        '"serviceBranchClassification":"A" }"rank":"SSG"}],"status":"SPONSOR" }"personAssociatedSet":[' \
        '{"id":"796121201" }"idType":"SSN" }"lastName":"WHITE" }"firstName":"CONNIE" }"middleName":"A" }' \
        '"cadencyName":"" }"deceased":false,"birthDate":"1935-07-12T08:00:00Z" }"gender":"FEMALE" }' \
        '"edi":1005079140,"associationReason":"SPOUSE" }"benefits":["21"],"personnels":[],"status":"DEPENDENT" }' \
        '"relationshipTypes":["FAMILY"],"permissionTypes":["NON_CLINICAL"]}]}}'
    }
    fediam_not_on_or_after { '2021-02-12T17:47:41Z' }
    aud { 'VAMobile' }
    fediam_mcid { 'WSSOE2102121242404971252931639' }
    fediamidsource { 'ssoe' }
    fediam_vaafi_proof_authority { 'DMDC' }
    phone_number { '(333)444-5555' }
    tokens_generated_by { 'OAuth AZN Code Flow' }
    fediamissuer { 'https://sqa.eauth.va.gov/isam/sps/saml20idp/saml20' }
    fediamproofing_auth { 'DMDC' }
    fediam_authentication_method { 'urn:oasis:names:tc:SAML:2.0:ac:classes:Password' }
    fediamam_eai_xattr_session_lifetime { '1613155361' }
    fediam_suffix { 'NOT_FOUND' }
    sub { '0000027792' }
    fediam_mhv_ien { '14398876' }
    fediam_authentication_instant { '2021-02-12T17:42:41Z' }
    token_type { 'bearer' }
    fediam_common_name { 'GREG ANDERSON' }
    fediam_sponsor_do_dedipn_id { '1005079124' }
    scope { 'openid' }
    fediam_npi { 'NOT_FOUND' }
    fediam_postal_code { '80129-6676' }
    fediam_vaafi_csp_id { '200DOD_1005079124' }
    fediam_pn_id { '796121200' }
    fediam_pn_id_type { 'SSN' }
    iat { 1_613_151_767 }
    email { 'veteran@gmail.asd' }
    code_challenge_method { 'S256' }
    given_name { 'GREG' }
    middle_name { 'A' }
    fediamassur_level { '2' }
    fediam_not_before { '2021-02-12T17:37:41Z' }
    fediam_prefix { 'NOT_FOUND' }
    fediam_state { 'CO' }
    fediam_city { 'HIGHLANDS RANCH' }
    fediam_pid { '600036159' }
    family_name { 'ANDERSON' }
    username { '0000027792' }

    initialize_with { attributes }
  end

  factory :mhv_premium_introspection_payload, class: Hash do
    fediamtransaction_id { 'BO1rf1VBdAsPGVdNfyg5/1/Q6dV7CA6Dk+dPLg5o2M0=' }
    fediam_is_delegate { 'false' }
    fediam_birls_number { 'NOT_FOUND' }
    birthdate { '1970-08-18' }
    fediamss_issue_instant { '2021-02-12T18:01:17Z' }
    fediam_mviicn { '1012853893V362415' }
    fediam_street { 'NOT_FOUND' }
    fediamsecid { '1012853893' }
    client_id { 'VAMobile' }
    fediam_country { 'NOT_FOUND' }
    fediam_gender { 'MALE' }
    exp { 1_613_154_684 }
    code_challenge { 'foHWImw_789-f14zzYZj3AX6o-HBEVIbpAi3mvNeHOY' }
    fediam_street1 { 'NOT_FOUND' }
    fediam_do_dedipn_id { 'NOT_FOUND' }
    fediam_gc_id {
      '1012853893V362415^NI^200M^USVHA^P|943574^PI^979^USVHA^A|20221^PI^200VETS^USDVA^A|' \
        'da4ae1e5ef9d479084f66563457a2dc3^PN^200VIDM^USDVA^A|1012853893^PN^200PROV^USDVA^A|' \
        '12403029^PI^200MH^USVHA^A|12403029^PI^200MHS^USVHA^A|438b7fbd26c5417ab57e0430e366c31d^PN^200VIDM^USDVA^A'
    }
    active { true }
    fediamauth_n_type { 'MHV' }
    fediam_not_on_or_after { '2021-02-12T18:06:18Z' }
    aud { 'VAMobile' }
    fediam_mcid { 'WSSOE2102121301177192038357306' }
    fediamidsource { 'ssoe' }
    fediam_vaafi_proof_authority { 'FICAM' }
    phone_number { 'NOT_FOUND' }
    tokens_generated_by { 'OAuth AZN Code Flow' }
    fediamissuer { 'https://sqa.eauth.va.gov/isam/sps/saml20idp/saml20' }
    fediamproofing_auth { 'FICAM' }
    fediam_authentication_method { 'urn:oasis:names:tc:SAML:2.0:ac:classes:Password' }
    fediamam_eai_xattr_session_lifetime { '1613156478' }
    fediam_suffix { 'NOT_FOUND' }
    sub { '1012853893' }
    fediam_mhv_ien { '12403029' }
    fediam_authentication_instant { '2021-02-12T18:01:18Z' }
    token_type { 'bearer' }
    fediam_common_name { 'easton1@mhv.va.gov' }
    scope { 'openid' }
    fediam_npi { 'NOT_FOUND' }
    fediam_postal_code { 'NOT_FOUND' }
    fediam_vaafi_csp_id { '200MH_12403029' }
    fediam_pn_id { '666700746' }
    fediam_pn_id_type { 'SSN' }
    iat { 1_613_152_884 }
    email { 'NOT_FOUND' }
    code_challenge_method { 'S256' }
    given_name { 'EASTON' }
    middle_name { 'NOT_FOUND' }
    fediamassur_level { '2' }
    fediam_not_before { '2021-02-12T17:56:18Z' }
    fediam_prefix { 'NOT_FOUND' }
    fediam_state { 'NOT_FOUND' }
    fediam_city { 'NOT_FOUND' }
    fediam_pid { 'NOT_FOUND' }
    family_name { 'GPTESTSYSSEVEN' }
    username { '1012853893' }

    initialize_with { attributes }
  end

  factory :idme_loa3_introspection_payload, class: Hash do
    fediamtransaction_id { '5eWibth5T4By92LinZBrcRi+dMHCkde5bhzwwVeOmPI' }
    fediam_is_delegate { 'false' }
    fediam_birls_number { '796121200' }
    birthdate { '1970-08-12' }
    fediamss_issue_instant { '2020-08-05T21:48:38Z' }
    fediam_mviicn { '1008596379V859838' }
    fediam_street { '1700 University Boulevard' }
    fediamsecid { '0000028114' }
    client_id { 'VAMobile' }
    fediam_country { 'NOT_FOUND' }
    fediam_gender { 'MALE' }
    exp { 1_596_667_726 }
    code_challenge { 'tDKCgVeM7b8X2Mw7ahEeSPPFxr7TGPc25IV5ex0PvHI' }
    fediam_street1 { '1700 University Boulevard' }
    fediam_do_dedipn_id { '1005079124' }
    fediam_gc_id {
      '1008596379V859838^NI^200M^USVHA^P|796121200^PI^200BRLS^USVBA^A|' \
        '0000028114^PN^200PROV^USDVA^A|1005079124^NI^200DOD^USDOD^A|' \
        '32331150^PI^200CORP^USVBA^A|' \
        '85c50aa76934460c8736f687a6a30546^PN^200VIDM^USDVA^A|' \
        '2810777^PI^200CORP^USVBA^A|32324397^PI^200CORP^USVBA^A|' \
        '19798466a4b143748e664482c6b6b81b^PN^200VIDM^USDVA^A|' \
        '796121200^AN^200CORP^USVBA^'
    }
    active { true }
    fediamauth_n_type { 'IDME' }
    fediam_not_on_or_after { '2020-08-05T21:53:42Z' }
    aud { 'VAMobile' }
    fediam_mcid { 'WSSOE2008051748411450069042554' }
    fediamidsource { 'ssoe' }
    fediam_vaafi_proof_authority { 'FICAM' }
    phone_number { '(858)335-0190' }
    tokens_generated_by { 'OAuth AZN Code Flow' }
    fediamissuer { 'https://int.eauth.va.gov/isam/sps/saml20idp/saml20' }
    fediamproofing_auth { 'FICAM' }
    fediam_authentication_method { 'http://idmanagement.gov/ns/assurance/loa/3' }
    fediamam_eai_xattr_session_lifetime { '1596667722' }
    fediam_suffix { 'NOT_FOUND' }
    sub { '0000028114' }
    fediam_mhvien { 'NOT_FOUND' }
    fediam_authentication_instant { '2020-08-05T21:48:42Z' }
    token_type { 'bearer' }
    fediam_common_name { 'va.api.user+idme.008@gmail.com' }
    scope { 'openid' }
    fediam_postal_code { '78665' }
    fediam_vaafi_csp_id { '200VIDM_19798466a4b143748e664482c6b6b81b' }
    fediam_pn_id { '796121200' }
    fediam_pn_id_type { 'SSN' }
    iat { 1_596_664_126 }
    email { 'va.api.user+idme.008@gmail.com' }
    code_challenge_method { 'S256' }
    given_name { 'GREG' }
    middle_name { 'A' }
    fediamassur_level { '3' }
    fediam_not_before { '2020-08-05T21:43:42Z' }
    fediam_prefix { 'NOT_FOUND' }
    fediam_state { 'TX' }
    fediam_city { 'Round Rock' }
    fediam_pid { '32331150,2810777,32324397' }
    family_name { 'ANDERSON' }
    username { '0000028114' }

    initialize_with { attributes }
  end

  factory :logingov_ial2_introspection_payload, class: Hash do
    fediamtransaction_id { '3wlWGAfhBKPFi8O1ToVhXz0kVGYieq7pMw8zYrjj3TE' }
    fediam_is_delegate { 'false' }
    fediam_birls_number { 'NOT_FOUND' }
    birthdate { '1982-07-04' }
    fediamss_issue_instant { '2021-11-10T16:51:27Z' }
    fediam_mviicn { '1200049153V217987' }
    fediam_street { '700 21st St South' }
    fediamsecid { '1200049153' }
    client_id { 'VAMobile' }
    fediam_country { 'NOT_FOUND' }
    fediam_gender { 'FEMALE' }
    exp { 1_596_667_726 }
    code_challenge { 'tDKCgVeM7b8X2Mw7ahEeSPPFxr7TGPc25IV5ex0PvHI' }
    fediam_street1 { '700 21st St South' }
    fediam_do_dedipn_id { 'NOT_FOUND' }
    fediam_gc_id {
      '1200049153V217987^NI^200M^USVHA^P|65f9f3b5-5449-47a6-b272-9d6019e7c2e3^PN^200VLGN^USDVA^A|' \
        '1200049153^PN^200PROV^USDVA^A|67f687a8ecd3448fbed4e5489b7eafc9^PN^200VIDM^USDVA^A'
    }
    active { true }
    fediamauth_n_type { 'LOGINGOV' }
    fediam_not_on_or_after { '2021-11-10T16:56:27' }
    aud { 'VAMobile' }
    fediam_mcid { 'WSSOE2111101151267411988803863' }
    fediamidsource { 'ssoe' }
    fediam_vaafi_proof_authority { 'FICAM' }
    phone_number { '(202)123-0203' }
    tokens_generated_by { 'OAuth AZN Code Flow' }
    fediamissuer { 'https://int.eauth.va.gov/isam/sps/saml20idp/saml20' }
    fediamproofing_auth { 'FICAM' }
    fediam_authentication_method { 'http://idmanagement.gov/ns/assurance/ial/2' }
    fediamam_eai_xattr_session_lifetime { '1596667722' }
    fediam_suffix { 'NOT_FOUND' }
    sub { '1200049153' }
    fediam_mhvien { '65f9f3b5-5449-47a6-b272-9d6019e7c2e3' }
    fediam_authentication_instant { '2021-11-10T16:51:26Z' }
    token_type { 'bearer' }
    fediam_common_name { 'va.api.user+logingov.123@gmail.com' }
    scope { 'openid' }
    fediam_postal_code { '22202' }
    fediam_vaafi_csp_id { '200VLGN_65f9f3b5-5449-47a6-b272-9d6019e7c2e3' }
    fediam_pn_id { '123123123' }
    fediam_pn_id_type { 'SSN' }
    iat { 1_596_664_126 }
    email { 'va.api.user+logingov.123@gmail.com' }
    code_challenge_method { 'S256' }
    given_name { 'Tessa' }
    middle_name { 'A' }
    fediamassur_level { '3' }
    fediam_not_before { '2021-11-10T16:46:27Z' }
    fediam_prefix { 'NOT_FOUND' }
    fediam_state { 'VA' }
    fediam_city { 'Arlington' }
    fediam_pid { 'NOT_FOUND' }
    family_name { 'WHIPPLE' }
    username { '1200049153' }

    initialize_with { attributes }
  end
end
