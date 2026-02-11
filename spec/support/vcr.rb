# frozen_string_literal: true

VCR.configure do |c|
  c.cassette_library_dir = 'spec/support/vcr_cassettes'
  c.hook_into :webmock
  # experiencing VCR-induced frustation? uncomment this:
  # c.debug_logger = File.open('vcr.log', 'w')

  c.filter_sensitive_data('<APP_TOKEN>') { Settings.mhv.rx.app_token }
  c.filter_sensitive_data('<AV_KEY>') { VAProfile::Configuration::SETTINGS.address_validation.api_key }
  c.filter_sensitive_data('<BENEFITS_INTAKE_SERVICE_API_KEY>') { Settings.benefits_intake_service.api_key }
  c.filter_sensitive_data('<CLAIMS_API_BD_URL>') { Settings.claims_api.benefits_documents.host }
  c.filter_sensitive_data('<CLAIMS_EVIDENCE_API_URL>') { Settings.claims_evidence_api.base_url }
  c.filter_sensitive_data('<DMC_TOKEN>') { Settings.dmc.client_secret }
  c.filter_sensitive_data('<DMC_BASE_URL>') { Settings.dmc.url }
  c.filter_sensitive_data('<BGS_BASE_URL>') { Settings.bgs.url }
  c.filter_sensitive_data('<EE_PASS>') { Settings.hca.ee.pass }
  c.filter_sensitive_data('<EVSS_AWS_BASE_URL>') { Settings.evss.aws.url }
  c.filter_sensitive_data('<EVSS_BASE_URL>') { Settings.evss.url }
  c.filter_sensitive_data('<EVSS_DVP_BASE_URL>') { Settings.evss.dvp.url }
  c.filter_sensitive_data('<FES_BASE_URL>') { Settings.claims_api.fes.service_url }
  c.filter_sensitive_data('<FARADAY_VERSION>') { Faraday::Connection::USER_AGENT }
  c.filter_sensitive_data('<DISABILITY_MAX_RATINGS_URI>') { Settings.disability_max_ratings_api.url }
  c.filter_sensitive_data('<GIDS_URL>') { Settings.gids.url }
  c.filter_sensitive_data('<LIGHTHOUSE_API_KEY>') { Settings.decision_review.api_key }
  c.filter_sensitive_data('<LIGHTHOUSE_API_KEY>') { Settings.lighthouse.facilities.api_key }
  c.filter_sensitive_data('<LIGHTHOUSE_BENEFITS_DISCOVERY_HOST>') { Settings.lighthouse.benefits_discovery.host }
  c.filter_sensitive_data('<LIGHTHOUSE_CLAIMS_API_HOST>') { Settings.lighthouse.benefits_claims.host }
  c.filter_sensitive_data('<LIGHTHOUSE_DIRECT_DEPOSIT_HOST>') { Settings.lighthouse.direct_deposit.host }
  c.filter_sensitive_data('<LIGHTHOUSE_BRD_API_KEY>') { Settings.brd.api_key }
  c.filter_sensitive_data('<LIGHTHOUSE_TV_API_KEY>') { Settings.claims_api.token_validation.api_key }
  c.filter_sensitive_data('<LIGHTHOUSE_BASE_URL>') { Settings.lighthouse.benefits_documents.host }
  c.filter_sensitive_data('<MDOT_KEY>') { Settings.mdot.api_key }
  c.filter_sensitive_data('<MDOT_URL>') { Settings.mdot.url }
  c.filter_sensitive_data('<MHV_HOST>') { Settings.mhv.rx.host }
  c.filter_sensitive_data('<MHV_UHD_HOST>') { Settings.mhv.uhd.host }
  c.filter_sensitive_data('<MHV_UHD_SECURITY_HOST>') { Settings.mhv.uhd.security_host }
  c.filter_sensitive_data('<MHV_MR_HOST>') { Settings.mhv.medical_records.host }
  c.filter_sensitive_data('<MHV_MR_X_AUTH_KEY>') { Settings.mhv.medical_records.x_auth_key }
  c.filter_sensitive_data('<MHV_MR_APP_TOKEN>') { Settings.mhv.medical_records.app_token }
  c.filter_sensitive_data('<MHV_X_API_KEY>') { Settings.mhv.medical_records.mhv_x_api_key }
  c.filter_sensitive_data('<MHV_MR_X_API_KEY>') { Settings.mhv.medical_records.x_api_key }
  c.filter_sensitive_data('<MHV_MR_X_API_KEY_V2>') { Settings.mhv.medical_records.x_api_key_v2 }
  c.filter_sensitive_data('<MHV_SM_APP_TOKEN>') { Settings.mhv.sm.app_token }
  c.filter_sensitive_data('<MHV_SM_HOST>') { Settings.mhv.api_gateway.hosts.sm_patient }
  c.filter_sensitive_data('<MPI_URL>') { IdentitySettings.mvi.url }
  c.filter_sensitive_data('<PD_TOKEN>') { Settings.maintenance.pagerduty_api_token }
  c.filter_sensitive_data('<OGC_ATTORNEY_EXCEL_LIST_URI>') do
    Settings.representation_management.ogc_attorney_excel_list_uri
  end
  c.filter_sensitive_data('<OGC_CLAIMS_AGENT_EXCEL_LIST_URI>') do
    Settings.representation_management.ogc_claims_agent_excel_list_uri
  end
  c.filter_sensitive_data('<OGC_ORGANIZATIONS_EXCEL_LIST_URI>') do
    Settings.representation_management.ogc_organizations_excel_list_uri
  end
  c.filter_sensitive_data('<CENTRAL_MAIL_TOKEN>') { Settings.central_mail.upload.token }
  c.filter_sensitive_data('<PPMS_API_KEY>') { Settings.ppms.api_keys }
  c.filter_sensitive_data('<PRENEEDS_HOST>') { Settings.preneeds.host }
  c.filter_sensitive_data('<VETS360_URL>') { Settings.vet360.url }
  c.filter_sensitive_data('<MULESOFT_SECRET>') { Settings.form_10_10cg.carma.mulesoft.client_secret }
  c.filter_sensitive_data('<SHAREPOINT_CLIENT_SECRET>') { Settings.vha.sharepoint.client_secret }
  c.filter_sensitive_data('<TRAVEL_PAY_BASE_URL>') { Settings.travel_pay.base_url }
  c.filter_sensitive_data('<ADDRESS_VALIDATION>') { VAProfile::Configuration::SETTINGS.address_validation.hostname }
  c.filter_sensitive_data('<X_API_KEY>') { Settings.mhv.rx.x_api_key }
  c.filter_sensitive_data('<LIGHTHOUSE_BENEFITS_EDUCATION_RSA_KEY_PATH>') do
    Settings.lighthouse.benefits_education.rsa_key
  end
  c.filter_sensitive_data('<LIGHTHOUSE_BENEFITS_EDUCATION_CLIENT_ID>') do
    Settings.lighthouse.benefits_education.client_id
  end
  c.filter_sensitive_data('<LIGHTHOUSE_BENEFITS_INTAKE_API_KEY>') do
    Settings.lighthouse.benefits_intake.api_key
  end
  c.filter_sensitive_data('<LIGHTHOUSE_BENEFITS_INTAKE_URL>') do
    BenefitsIntake::Service.configuration.service_path
  end
  c.filter_sensitive_data('<VEIS_AUTH_URL>') { Settings.travel_pay.veis.auth_url }
  c.filter_sensitive_data('<CONTENTION_CLASSIFICATION_API_URL>') { Settings.contention_classification_api.url }
  c.filter_sensitive_data('<VA_MOBILE_URL>') { Settings.va_mobile.url }
  c.filter_sensitive_data('<VAOS_PATIENTS_PATH>') { Settings.va_mobile.patients_path }
  c.filter_sensitive_data('<BENEFITS_CLAIMS_PATH>') { Settings.va_mobile.claims_path }
  c.filter_sensitive_data('<ARP_ALLOW_LIST_ACCESS_TOKEN>') do
    Settings.accredited_representative_portal.allow_list.github.access_token
  end
  c.filter_sensitive_data('<ARP_ALLOW_LIST_BASE_URI>') do
    Settings.accredited_representative_portal.allow_list.github.base_uri
  end
  c.filter_sensitive_data('<ARP_ALLOW_LIST_REPO>') { Settings.accredited_representative_portal.allow_list.github.repo }
  c.filter_sensitive_data('<ARP_ALLOW_LIST_PATH>') { Settings.accredited_representative_portal.allow_list.github.path }
  c.filter_sensitive_data('<ARP_BENEFITS_CLAIMS_PATH>') do
    Settings.accredited_representative_portal.lighthouse.benefits_claims.path
  end
  c.filter_sensitive_data('<VAOS_CCRA_API_URL>') { Settings.vaos.ccra.api_url }
  c.filter_sensitive_data('<VAOS_EPS_TOKEN_URL>') { Settings.vaos.eps.access_token_url }
  c.filter_sensitive_data('<VAOS_EPS_API_URL>') { Settings.vaos.eps.api_url }
  c.filter_sensitive_data('<VAOS_EPS_API_PATH>') { Settings.vaos.eps.base_path }
  c.filter_sensitive_data('<TRAVEL_CLAIM_API_URL>') { TravelClaim::Configuration.instance.base_path }
  c.filter_sensitive_data('<VETERAN_ENROLLMENT_SYSTEM_BASE_URI>') do
    "#{Settings.veteran_enrollment_system.host}:#{Settings.veteran_enrollment_system.port}"
  end
  c.filter_sensitive_data('<VETERAN_ENROLLMENT_SYSTEM>') { Settings.hca.endpoint }
  c.filter_sensitive_data('<CASEFLOW_API_HOST>') { Settings.caseflow.host }
  c.filter_sensitive_data('<DGI_VETS_URL>') { Settings.dgi.vets.url }
  c.filter_sensitive_data('<LIGHTHOUSE_HCC_HOST>') do
    Settings.lighthouse.healthcare_cost_and_coverage.host
  end
  c.filter_sensitive_data('<VASS_AUTH_URL>') { Settings.vass.auth_url }
  c.filter_sensitive_data('<VASS_API_URL>') { Settings.vass.api_url }
  c.before_record do |i|
    %i[response request].each do |env|
      next unless i.send(env).headers.keys.include?('Token')

      i.send(env).headers.update('Token' => '<SESSION_TOKEN>')
    end
  end

  c.before_record do |i|
    %i[response request].each do |env|
      next unless i.send(env).headers.keys.include?('Authorization')

      i.send(env).headers.update('Authorization' => 'Bearer <TOKEN>')
    end
  end

  c.register_request_matcher :sm_user_ignoring_path_param do |request1, request2|
    # Matches, ignoring the user id and icn after `/isValidSMUser/` to handle any user id and icn
    # E.g. <HOST>mhvapi/v1/usermgmt/usereligibility/isValidSMUser/10000000/1000000000V000000
    path1 = request1.uri.gsub(%r{/isValidSMUser/.*}, '/isValidSMUser')
    path2 = request2.uri.gsub(%r{/isValidSMUser/.*}, '/isValidSMUser')
    path1 == path2
  end
end
