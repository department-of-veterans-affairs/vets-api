# vets-api Module Mapping

Generated: 2025-12-12T12:06:32-0600

## Summary

| Metric | Count |
|--------|-------|
| Total Modules | 42 |
| Mounted Modules | 38 |
| Unmounted Modules | 4 |
| Modules With Gemfile | 42 |
| Total Controllers | 287 |
| Total Services | 292 |
| Total Models | 266 |
| Total Specs | 1261 |

### Unmounted Modules

- `ask_va_api`
- `banners`
- `travel_claims`
- `vba_documents`

## Module Details

### accredited_representative_portal

**Mount Path:** `/accredited_representative_portal`

**Has Gemfile:** ✓

**Controllers:** 10
  - `application_controller` (7 actions)
    - Actions: deny_access_unless_form_enabled, routing_error, track_unique_session, verify_pundit_authorization, handle_exceptions, log_auth_failure, log_unexpected_error
  - `claim_submissions_controller` (9 actions)
    - Actions: index, pagination_meta, validated_params, params_schema, sort_params, page, per_page, claim_submissions, scope_includes
  - `claimant_controller` (1 actions)
    - Actions: search
  - `form21a_controller` (16 actions)
    - Actions: initialize, background_detail_upload, submit, schema, handle_logging, handle_file_save, handle_response, current_in_progress_form_or_routing_error, current_in_progress_form, update_in_progress_form, feature_enabled, loa3_user, parse_request_body, validate_form, handle_json_error, render_ogc_service_response
  - `in_progress_forms_controller` (7 actions)
    - Actions: show, update, destroy, feature_enabled, find_form, build_form, build_form_for_user
  - `intent_to_file_controller` (10 actions)
    - Actions: show, create, veteran_form, claimant_form, form, check_feature_toggle, service, icn, validate_file_type, claimant_representative
  - `power_of_attorney_request_decisions_controller` (9 actions)
    - Actions: create, process_acceptance, process_declination, track_decision_durations, render_invalid_type_error, decision_params, send_declination_email, poa_code, ar_monitoring
  - `power_of_attorney_requests_controller` (19 actions)
    - Actions: index, show, params_schema, validated_params, poa_requests, filter_by_status, sort_params, page, per_page, status, pending, processed, as_selected_individual, filter_by_current_user, scope_includes, pagination_meta, poa_code, poa_codes, ar_monitoring
  - `representative_form_upload_controller` (14 actions)
    - Actions: submit, upload_scanned_form, upload_supporting_documents, form_id, send_confirmation_email, monitor, intake_service, authorize_attachment_upload, authorize_submission, handle_attachment_upload, ar_monitoring, form_class, organization, trace_key_tags
  - `representative_users_controller` (3 actions)
    - Actions: show, authorize_as_representative, in_progress_forms

**Services:** 16
  - `accreditation_service`
  - `benefits_intake_service`
  - `claimant_lookup_service`
  - `email_delivery_status_callback`
  - `enable_online_submission_21_22_service`
  - ...

**Models:** 18
  - `claimant_representative`
  - `form21a_attachment`
  - `icn_temporary_identifier`
  - `power_of_attorney_form`
  - `power_of_attorney_form_submission`
  - ...

**Routes:** 9
  - `GET authorize_as_representative`
  - `GET user`
  - `POST form21a`
  - `POST :details_slug`
  - `POST /submit_representative_form`
  - `POST /representative_form_upload`
  - `POST /upload_supporting_documents`
  - `POST search`
  - `GET intent_to_file`

**Shared Concerns Used:**
  - `Vets::SharedLogging`

**Tests:** 61 total (12 request, 13 model, 14 service)

---

### appeals_api

**Mount Path:** `/appeals`

**Has Gemfile:** ✓

**Controllers:** 27
  - `appealable_issues_controller` (9 actions)
    - Actions: index, schema, header_names, request_headers, validate_json_schema, token_validation_api_key, get_caseflow_response, generate_caseflow_headers, format_caseflow_response
  - `application_controller` (6 actions)
    - Actions: render_response, deactivate_endpoint, sunset_date, set_default_headers, set_extra_context, model_errors_to_json_api
  - `api_controller` (1 actions)
    - Actions: index
  - `docs_controller` (3 actions)
    - Actions: decision_reviews, appeals_status, decision_reviews_swagger_json
  - `docs_controller` (7 actions)
    - Actions: decision_reviews, hlr, nod, sc, ai, la, swagger_file
  - `higher_level_reviews_controller` (13 actions)
    - Actions: schema, index, show, validate, create, download, header_names, validate_json_schema, request_headers, render_higher_level_review, render_higher_level_review_not_found, render_model_errors, token_validation_api_key
  - `legacy_appeals_controller` (5 actions)
    - Actions: index, schema, validate_json_schema, get_caseflow_response, token_validation_api_key
  - `metadata_controller` (16 actions)
    - Actions: decision_reviews, appeals_status, healthcheck, healthcheck_s3, s3_is_healthy, mail_status_upstream_healthcheck, appeals_status_upstream_healthcheck, decision_reviews_upstream_healthcheck, set_default_headers, health_checker, render_upstream_services_response, upstream_service_details, service_details_response, decision_reviews_versions, decision_reviews_v1, decision_reviews_v2
  - `evidence_submissions_controller` (4 actions)
    - Actions: show, create, validate_token_nod_access, token_validation_api_key
  - `notice_of_disagreements_controller` (12 actions)
    - Actions: show, create, download, validate, schema, validate_json_schema, render_notice_of_disagreement, render_notice_of_disagreement_not_found, render_model_errors, header_names, request_headers, token_validation_api_key
  - `shared_schemas_controller` (8 actions)
    - Actions: show, uri, api_name, api_version, schema_form_name, schema_type, check_schema_type, invalid_schema_type_error
  - `evidence_submissions_controller` (4 actions)
    - Actions: show, create, validate_token_sc_access, token_validation_api_key
  - `supplemental_claims_controller` (14 actions)
    - Actions: index, schema, show, validate, create, download, evidence_submission_indicated, validate_json_schema, render_supplemental_claim, render_supplemental_claim_not_found, header_names, request_headers, render_model_errors, token_validation_api_key
  - `appeals_controller` (6 actions)
    - Actions: index, consumer, ssn, requesting_va_user, header, target_veteran
  - `appeals_controller` (5 actions)
    - Actions: index, required_header, ssn, get_caseflow_response, token_validation_api_key
  - `base_contestable_issues_controller` (14 actions)
    - Actions: index, request_headers, caseflow_request_headers, get_contestable_issues_from_caseflow, benefit_type, decision_review_type, filtered_caseflow_response, caseflow_response_has_a_body_and_a_status, caseflow_returned_a_4xx, caseflow_response_from_backend_service_exception, render_unusable_response_error, validate_headers, render_validation_errors, log_caseflow_error
  - `contestable_issues_controller` (1 actions)
    - Actions: decision_review_type
  - `evidence_submissions_controller` (8 actions)
    - Actions: show, create, header_names, nod_uuid_present, nod_uuid_missing_error, submission_attributes, request_headers, log_error
  - `notice_of_disagreements_controller` (15 actions)
    - Actions: show, create, validate, schema, header_names, validate_json_schema, validation_success, request_headers, new_notice_of_disagreement, api_version, render_model_errors, find_notice_of_disagreement, render_notice_of_disagreement_not_found, render_notice_of_disagreement, deprecate_headers
  - `contestable_issues_controller` (20 actions)
    - Actions: index, header_names, get_contestable_issues_from_caseflow, filtered_caseflow_response, caseflow_response_has_a_body_and_a_status, caseflow_returned_a_4xx, caseflow_response_from_backend_service_exception, render_unusable_response_error, decision_review_type, benefit_type, validate_params, validate_receipt_date_header, invalid_decision_review_type, invalid_benefit_type, render_unprocessable_entity, request_headers, caseflow_request_headers, validate_json_schema, caseflow_benefit_type_mapping, log_caseflow_error
  - `contestable_issues_controller` (3 actions)
    - Actions: index, validate_receipt_date_header, decision_review_type
  - `higher_level_reviews_controller` (17 actions)
    - Actions: index, show, create, validate, schema, download, header_names, validate_icn_header, validate_json_schema, validate_json_schema_for_pdf_fit, validation_success, request_headers, new_higher_level_review, render_model_errors, find_higher_level_review, render_higher_level_review_not_found, render_higher_level_review
  - `legacy_appeals_controller` (10 actions)
    - Actions: index, header_names, request_headers, caseflow_request_headers, validate_json_schema, get_legacy_appeals_from_caseflow, caseflow_response_usable, caseflow_returned_a_4xx, caseflow_exception, render_unusable_response_error
  - `evidence_submissions_controller` (8 actions)
    - Actions: show, create, header_names, nod_uuid_present, nod_uuid_missing_error, submission_attributes, request_headers, log_error
  - `notice_of_disagreements_controller` (16 actions)
    - Actions: index, show, create, download, validate, schema, header_names, validate_icn_header, validate_json_schema, validation_success, request_headers, new_notice_of_disagreement, render_model_errors, find_notice_of_disagreement, render_notice_of_disagreement_not_found, render_notice_of_disagreement
  - `evidence_submissions_controller` (8 actions)
    - Actions: show, create, header_names, supplemental_claim_uuid, uuid_missing_error, submission_attributes, request_headers, log_error
  - `supplemental_claims_controller` (15 actions)
    - Actions: index, show, create, validate, schema, download, header_names, validate_icn_header, validate_json_schema, validation_success, request_headers, render_model_errors, render_supplemental_claim_not_found, render_errors, evidence_submission_indicated

**Services:** 51
  - `central_mail_updater`
  - `evidence_submission_request_validator`
  - `line_of_business`
  - `generator`
  - `form_data`
  - ...

**Models:** 15
  - `appellant`
  - `evidence_submission`
  - `phone`
  - `higher_level_review`
  - `notice_of_disagreement`
  - ...

**Routes:** 40
  - `GET /appeals_status/metadata`
  - `GET /decision_reviews/metadata`
  - `GET /v0/healthcheck`
  - `GET /v1/healthcheck`
  - `GET /v2/healthcheck`
  - `GET /v0/upstream_healthcheck`
  - `GET /v1/upstream_healthcheck`
  - `GET /v2/upstream_healthcheck`
  - `GET /v0/appeals`
  - `GET contestable_issues`
  - ...

**Tests:** 129 total (25 request, 10 model, 35 service)

---

### apps_api

**Mount Path:** `/apps`

**Has Gemfile:** ✓

**Controllers:** 3
  - `application_controller` (2 actions)
    - Actions: set_default_format_to_json, set_sentry_tags_and_extra_context
  - `api_controller` (1 actions)
    - Actions: index
  - `directory_controller` (8 actions)
    - Actions: index, show, create, update, destroy, scopes, set_directory_application, directory_application_params

**Models:** 1
  - `directory_application`

**Routes:** 4
  - `GET directory/scopes/:category`
  - `GET directory/scopes`
  - `RESOURCES directory`
  - `GET api`

**Tests:** 2 total (1 request, 1 model, 0 service)

---

### ask_va_api

**Mount Path:** `NOT MOUNTED`

**Has Gemfile:** ✓

**Controllers:** 6
  - `application_controller` (4 actions)
    - Actions: check_maintenance_mode_in_prod, handle_exceptions, log_and_render_error, log_error
  - `address_validation_controller` (3 actions)
    - Actions: create, address_params, service
  - `education_facilities_controller` (4 actions)
    - Actions: autocomplete, search, show, children
  - `health_facilities_controller` (13 actions)
    - Actions: search, show, retrieve_patsr_approved_facilities, api, lighthouse_params, serializer, resource_path, mobile_api, mobile_api_get_by_id, covid_mobile_params, handle_exceptions, log_and_render_error, log_error
  - `inquiries_controller` (15 actions)
    - Actions: index, show, create, unauth_create, download_attachment, profile, status, create_reply, process_inquiry, retriever, mock_service, inquiry_params, reply_params, fetch_parameters, require_loa3
  - `static_data_controller` (7 actions)
    - Actions: announcements, branch_of_service, contents, get_resource, constantize_class, mock_service, render_result

**Services:** 8
  - `redis_client`
  - `cache_data`
  - `crm_token`
  - `error_handler`
  - `service`
  - ...

**Routes:** 22
  - `GET /inquiries`
  - `GET /inquiries/:id`
  - `GET /inquiries/:id/status`
  - `GET /download_attachment`
  - `GET /profile`
  - `POST /inquiries/auth`
  - `POST /inquiries`
  - `POST /inquiries/:id/reply/new`
  - `GET /categories`
  - `GET /categories/:category_id/topics`
  - ...

**Tests:** 46 total (5 request, 0 model, 6 service)

---

### avs

**Mount Path:** `/avs`

**Has Gemfile:** ✓

**Controllers:** 2
  - `apidocs_controller` (1 actions)
    - Actions: index
  - `avs_controller` (11 actions)
    - Actions: index, show, avs_service, feature_enabled, get_avs_path, render_client_error, serializer, validate_search_param, validate_sid, normalize_icn, icns_match

**Services:** 4
  - `base_service`
  - `configuration`
  - `response`
  - `avs_service`

**Models:** 1
  - `after_visit_summary`

**Routes:** 2
  - `GET /avs/search`
  - `GET /avs/:sid`

**Shared Concerns Used:**
  - `Vets::Model`
  - `Vets::SharedLogging`

**Tests:** 4 total (2 request, 1 model, 1 service)

---

### banners

**Mount Path:** `NOT MOUNTED`

**Has Gemfile:** ✓

**Models:** 1
  - `banner`

**Tests:** 6 total (0 request, 1 model, 0 service)

---

### bpds

**Mount Path:** `/bpds`

**Has Gemfile:** ✓

**Models:** 2
  - `submission`
  - `submission_attempt`

**Tests:** 8 total (0 request, 2 model, 0 service)

---

### burials

**Mount Path:** `/burials`

**Has Gemfile:** ✓

**Controllers:** 1
  - `claims_controller` (10 actions)
    - Actions: show, create, create_claim, short_name, claim_class, process_attachments, filtered_params, log_validation_error_to_metadata, sanitize_attachments, monitor

**Models:** 2
  - `va_21p530ez`
  - `saved_claim`

**Tests:** 15 total (0 request, 1 model, 0 service)

---

### check_in

**Mount Path:** `/check_in`

**Has Gemfile:** ✓

**Controllers:** 12
  - `application_controller` (5 actions)
    - Actions: before_logger, after_logger, low_auth_token, low_auth_token, authorize
  - `patient_check_ins_controller` (2 actions)
    - Actions: show, create
  - `travel_claims_controller` (3 actions)
    - Actions: create, permitted_params, authorize
  - `patient_check_ins_controller` (2 actions)
    - Actions: show, create
  - `sessions_controller` (2 actions)
    - Actions: show, create
  - `travel_claims_controller` (10 actions)
    - Actions: create, permitted_params, authorize_travel_reimbursement, submit_travel_claim, handle_parameter_missing_error, handle_argument_error, handle_backend_service_error, map_status, scrubbed_detail, error_message_for_logging
  - `apidocs_controller` (1 actions)
    - Actions: index
  - `appointments_controller` (11 actions)
    - Actions: index, permitted_params, appt_struct_data, merge_facilities_and_clinic, check_in_session, appointments, appointments_service, facility_service, start_date, end_date, authorize
  - `demographics_controller` (2 actions)
    - Actions: update, permitted_params
  - `patient_check_ins_controller` (6 actions)
    - Actions: show, create, permitted_params, authorize, handoff, call_set_echeckin_started
  - `pre_check_ins_controller` (4 actions)
    - Actions: show, create, permitted_params, authorize
  - `sessions_controller` (5 actions)
    - Actions: show, create, permitted_params, pre_checkin, authorize

**Services:** 29
  - `client`
  - `redis_client`
  - `token_service`
  - `travel_claim_notification_callback`
  - `travel_claim_notification_utilities`
  - ...

**Models:** 3
  - `patient_check_in`
  - `patient_check_in`
  - `session`

**Routes:** 1
  - `GET apidocs`

**Shared Concerns Used:**
  - `Vets::SharedLogging`

**Tests:** 53 total (11 request, 3 model, 29 service)

---

### claims_api

**Mount Path:** `/claims`

**Has Gemfile:** ✓

**Controllers:** 21
  - `api_controller` (0 actions)
  - `api_controller` (1 actions)
    - Actions: index
  - `api_controller` (1 actions)
    - Actions: index
  - `metadata_controller` (3 actions)
    - Actions: index, version_1_docs, version_2_docs
  - `upstream_faraday_healthcheck_controller` (3 actions)
    - Actions: corporate, claimant, itf
  - `upstream_healthcheck_controller` (0 actions)
  - `application_controller` (18 actions)
    - Actions: fetch_aud, validate_veteran_identifiers, source_name, authenticate, claims_status_service, bgs_service, local_bgs_service, claims_service, bgs_claim_status_service, bgs_itf_service, header, header_request, target_veteran, veteran_from_headers, set_sentry_tags_and_extra_context, edipi_check, validate_header_values_format, claims_v1_logging
  - `claims_controller` (4 actions)
    - Actions: index, show, fetch_errored, format_evss_errors
  - `disability_compensation_controller` (19 actions)
    - Actions: submit_form_526, upload_form_526, upload_supporting_documents, validate_form_526, sanitize_account_type, flashes, special_issues_per_disability, special_issues_for_disability, validate_initial_claim, valid_526_response, veteran_middle_initial, format_526_errors, get_fes_data, v1_fes_mapper_service, fes_service, validate_with_service, build_validation_service, track_526_validation_errors, unprocessable_response
  - `intent_to_file_controller` (13 actions)
    - Actions: submit_form_0966, active, validate, intent_to_file_options, handle_claimant_fields, active, active_param, check_for_type, form_type, validation_success, check_for_invalid_burial_submission, veteran_submitting_burial_itf, request_includes_claimant_id
  - `power_of_attorney_controller` (19 actions)
    - Actions: submit_form_2122, upload, status, active, validate, update_auth_headers_for_dependent, validate_dependent_claimant, current_poa_begin_date, power_of_attorney_verifier, header_md5, header_hash, source_data, nullable_icn, find_poa_by_id, validation_success, build_representative_info, find_by_ssn, check_request_ssn_matches_mpi, check_file_number_exists
  - `application_controller` (12 actions)
    - Actions: schema, auth_headers, validate_request, authenticate, benefits_doc_api, bgs_service, local_bgs_service, bgs_claim_status_service, get_benefits_documents_auth_token, file_number_check, edipi_check, claims_v2_logging
  - `veteran_identifier_controller` (4 actions)
    - Actions: find, target_veteran, user_is_target_veteran, ccg_flow
  - `claims_controller` (35 actions)
    - Actions: index, show, bgs_phase_status_mapper, generate_show_output, map_claims, map_and_remove_duplicates, handle_remaining_lh_claims, find_bgs_claim_in_lighthouse_collection, find_lighthouse_claim, find_bgs_claim, find_bgs_claims, looking_for_lighthouse_claim, build_claim_structure, build_contentions, current_phase_back, latest_phase_type_change_indicator, latest_phase_type, get_current_status_from_hash, get_completed_phase_number_from_phase_details, get_bgs_phase_completed_dates, extract_date, format_bgs_phase_date, format_bgs_phase_chng_dates, detect_current_status, get_errors, cast_claim_lc_status, map_yes_no_to_boolean, waiver_boolean, map_status, uploads_allowed, accepted, overdue, supporting_document, find_tracked_item, build_claim_phase_attributes
  - `disability_compensation_controller` (25 actions)
    - Actions: validate, generate_pdf, synchronous, shared_submit_methods, generate_pdf_from_service, generate_pdf_mapper_service, generate_526_pdf, get_pdf_data_wrapper, veteran_middle_initial, flashes, shared_validation, valid_526_response, track_pact_counter, valid_pact_act_claim, save_auto_claim, pdf_generation_service, form526_establishment_service, queue_flash_updater, start_bd_uploader_job, errored_state_value, bd_service, sandbox_request, claims_load_testing, mocking, find_claim
  - `evidence_waiver_controller` (10 actions)
    - Actions: submit, set_lighthouse_claim, set_bgs_claim, verify_if_dependent_claim, dependent_service, create_ews, source_cid, find_lighthouse_claim, looking_for_lighthouse_claim, find_bgs_claim
  - `intent_to_file_controller` (16 actions)
    - Actions: type, submit, validate, validate_request_format, build_options_and_validate, build_intent_to_file_options, handle_claimant_fields, validate_ssn, check_for_invalid_survivor_submission, claimant_ssn_blank, claimant_id_equals_vet_id, claimant_ssn_equals_vet_ssn, get_bgs_type, itf_types, bgs_itf_to_lighthouse_itf, bgs_itf_service
  - `base_controller` (27 actions)
    - Actions: show, status, shared_form_validation, validate_registration_number, attributes, submit_power_of_attorney, set_auth_headers, add_dependent_to_auth_headers, validation_success, current_poa_code, current_poa, representative, format_representative, format_organization, header_md5, header_hash, get_poa_code, source_data, source_name, nullable_icn, user_profile, icn_for_vanotify, fetch_claimant, fetch_ptcpnt_id, claimant_icn, disable_jobs, add_claimant_data_to_form
  - `individual_controller` (3 actions)
    - Actions: submit, validate, validate_individual_poa_code
  - `organization_controller` (3 actions)
    - Actions: submit, validate, validate_org_poa_code
  - `request_controller` (34 actions)
    - Actions: index, show, decide, create, add_dependent_data_to_poa_response, get_dependent_name, process_poa_decision, validate_mapped_data, log_and_raise_decision_error_message, build_auth_headers, decide_request_attributes, build_veteran_or_dependent_data, manage_representative_update_poa_request, decide_service, manage_representative_service, find_poa_request, validate_country_code, validate_accredited_representative, validate_accredited_organization, build_bgs_attributes, validate_filter, validate_statuses, validate_page_size_and_number_params, use_defaults, verify_under_max_values, valid_page_param, build_params_error_msg, verify_poa_codes_data, page_number_to_index, normalize, veteran_data, claimant_data, representative_data, organization_data

**Services:** 33
  - `dependent_claimant_poa_assignment_service`
  - `dependent_claimant_verification_service`
  - `dependent_service`
  - `disability_document_service`
  - `form526_establishment_service`
  - ...

**Models:** 14
  - `auto_established_claim`
  - `evidence_waiver_submission`
  - `evss_claim`
  - `intent_to_file`
  - `power_of_attorney`
  - ...

**Routes:** 41
  - `GET /metadata`
  - `GET /:version/upstream_healthcheck`
  - `GET /:version/upstream_healthcheck/faraday/corporate`
  - `GET /:version/upstream_healthcheck/faraday/claimant`
  - `GET /:version/upstream_healthcheck/faraday/itf`
  - `GET 526`
  - `POST 526`
  - `PUT 526/:id`
  - `POST 526/validate`
  - `POST 526/:id/attachments`
  - ...

**Shared Concerns Used:**
  - `Vets::Model`
  - `Vets::SharedLogging`

**Tests:** 174 total (27 request, 8 model, 23 service)

---

### claims_evidence_api

**Mount Path:** `/claims_evidence_api`

**Has Gemfile:** ✓

**Models:** 2
  - `submission`
  - `submission_attempt`

**Tests:** 19 total (0 request, 2 model, 0 service)

---

### debts_api

**Mount Path:** `/debts_api`

**Has Gemfile:** ✓

**Controllers:** 5
  - `application_controller` (0 actions)
  - `digital_disputes_controller` (10 actions)
    - Actions: create, create_via_dmc, create_legacy, initialize_submission, render_validation_error, process_submission, parse_metadata, submission_params, email_notifications_enabled, send_submission_email
  - `financial_status_reports_calculations_controller` (10 actions)
    - Actions: total_assets, monthly_income, monthly_expenses, all_expenses, asset_form, income_form, expense_form, asset_calculator, income_calculator, expense_calculator
  - `financial_status_reports_controller` (14 actions)
    - Actions: create, transform_and_submit, download_pdf, submissions, rehydrate, render_not_found, full_name, address, name_amount, fsr_form, full_transform_form, service, full_transform_service, full_transform_logging
  - `one_debt_letters_controller` (3 actions)
    - Actions: combine_pdf, pdf_params, file_name_for_pdf

**Models:** 3
  - `digital_dispute`
  - `digital_dispute_submission`
  - `form5655_submission`

**Routes:** 7
  - `GET financial_status_reports/rehydrate_submission/:submission_id`
  - `POST financial_status_reports/transform_and_submit`
  - `POST calculate_total_assets`
  - `POST calculate_monthly_expenses`
  - `POST calculate_all_expenses`
  - `POST calculate_monthly_income`
  - `POST combine_one_debt_letter_pdf`

**Shared Concerns Used:**
  - `Vets::SharedLogging`

**Tests:** 32 total (4 request, 3 model, 0 service)

---

### decision_reviews

**Mount Path:** `/decision_reviews`

**Has Gemfile:** ✓

**Controllers:** 9
  - `application_controller` (1 actions)
    - Actions: set_csrf_header
  - `appeals_base_controller` (5 actions)
    - Actions: decision_review_service, request_body_hash, get_hash_from_request_body, request_body_is_not_a_hash_error, request_body_debug_data
  - `decision_review_evidences_controller` (5 actions)
    - Actions: serializer_klass, save_attachment_to_cloud, common_log_params, unlock_pdf, get_form_id_from_request_headers
  - `contestable_issues_controller` (2 actions)
    - Actions: index, merge_legacy_appeals
  - `contestable_issues_controller` (1 actions)
    - Actions: index
  - `notice_of_disagreements_controller` (4 actions)
    - Actions: show, create, error_class, handle_personal_info_error
  - `contestable_issues_controller` (2 actions)
    - Actions: index, merge_legacy_appeals
  - `supplemental_claims_controller` (14 actions)
    - Actions: show, create, post_create_log_msg, handle_4142, log_form4142_job_queued, submit_evidence, handle_personal_info_error, process_submission, create_appeal_submission, handle_saved_claim, clear_in_progress_form, error_class, normalize_evidence_retrieval_for_lighthouse_schema, merge_evidence_entries
  - `higher_level_reviews_controller` (4 actions)
    - Actions: show, create, error_class, handle_personal_info_error

**Routes:** 3
  - `GET contestable_issues(/:benefit_type)`
  - `GET contestable_issues`
  - `GET contestable_issues(/:benefit_type)`

**Tests:** 22 total (6 request, 0 model, 0 service)

---

### dependents_benefits

**Mount Path:** `/dependents_benefits`

**Has Gemfile:** ✓

**Controllers:** 1
  - `claims_controller` (8 actions)
    - Actions: show, create, dependent_params, stats_key, check_flipper_flag, create_dependent_service, dependency_verification_service, monitor

**Models:** 5
  - `add_remove_dependent`
  - `va_686c674`
  - `parent_dependency`
  - `primary_dependency_claim`
  - `school_attendance_approval`

**Shared Concerns Used:**
  - `Vets::Model`

**Tests:** 23 total (0 request, 4 model, 0 service)

---

### dependents_verification

**Mount Path:** `/dependents_verification`

**Has Gemfile:** ✓

**Controllers:** 1
  - `claims_controller` (11 actions)
    - Actions: short_name, claim_class, show, create, form_data_with_ssn_filenumber, veteran_file_number, check_flipper_flag, filtered_params, process_and_upload_to_lighthouse, log_validation_error_to_metadata, monitor

**Models:** 2
  - `va_210538`
  - `saved_claim`

**Routes:** 2
  - `POST form0538`
  - `GET form0538`

**Shared Concerns Used:**
  - `Vets::Model`

**Tests:** 11 total (0 request, 2 model, 0 service)

---

### dhp_connected_devices

**Mount Path:** `/dhp_connected_devices`

**Has Gemfile:** ✓

**Controllers:** 3
  - `apidocs_controller` (1 actions)
    - Actions: index
  - `fitbit_controller` (13 actions)
    - Actions: connect, callback, disconnect, fitbit_api, device_key, website_host_service, token_storage_service, callback_params, feature_enabled, user_verified, connection_unavailable_error, redirect_with_status, log_error
  - `veteran_device_records_controller` (1 actions)
    - Actions: index

**Services:** 3
  - `token_storage_service`
  - `veteran_device_records_service`
  - `website_host_service`

**Models:** 2
  - `device`
  - `veteran_device_record`

**Routes:** 5
  - `GET /apidocs`
  - `GET /veteran-device-records`
  - `GET fitbit`
  - `GET fitbit-callback`
  - `GET fitbit/disconnect`

**Shared Concerns Used:**
  - `Vets::SharedLogging`

**Tests:** 9 total (3 request, 2 model, 3 service)

---

### employment_questionnaires

**Mount Path:** `/employment_questionnaires`

**Has Gemfile:** ✓

**Controllers:** 1
  - `claims_controller` (9 actions)
    - Actions: short_name, claim_class, show, create, check_flipper_flag, process_attachments, filtered_params, log_validation_error_to_metadata, monitor

**Models:** 2
  - `va_214140`
  - `saved_claim`

**Routes:** 2
  - `POST form4140`
  - `GET form4140/:id`

**Tests:** 11 total (0 request, 1 model, 0 service)

---

### facilities_api

**Mount Path:** `/facilities_api`

**Has Gemfile:** ✓

**Controllers:** 4
  - `application_controller` (8 actions)
    - Actions: render_json, render_collection, render_record, meta_pagination, generate_pagination, generate_previous_page_link, generate_next_page_link, generate_links
  - `apidocs_controller` (1 actions)
    - Actions: index
  - `ccp_controller` (14 actions)
    - Actions: index, urgent_care, provider, pharmacy, specialties, api, ppms_params, ppms_action_params, ppms_provider_params, ppms_search, urgent_care, provider_urgent_care, resource_path, provider_locator
  - `va_controller` (9 actions)
    - Actions: search, show, api, lighthouse_params, serializer, resource_path, mobile_api, mobile_api_get_by_id, covid_mobile_params

**Services:** 11
  - `client`
  - `configuration`
  - `errors`
  - `response`
  - `client`
  - ...

**Models:** 5
  - `facility`
  - `service`
  - `provider`
  - `specialty`
  - `std_institution_facility`

**Routes:** 7
  - `GET urgent_care`
  - `GET provider`
  - `GET pharmacy`
  - `GET specialties`
  - `GET va/:id`
  - `POST va`
  - `GET apidocs`

**Shared Concerns Used:**
  - `Vets::Model`

**Tests:** 13 total (3 request, 5 model, 4 service)

---

### income_and_assets

**Mount Path:** `/income_and_assets`

**Has Gemfile:** ✓

**Controllers:** 1
  - `claims_controller` (10 actions)
    - Actions: short_name, claim_class, show, create, check_flipper_flag, process_attachments, filtered_params, log_validation_error_to_metadata, sanitize_attachments, monitor

**Models:** 2
  - `va_21p0969`
  - `saved_claim`

**Routes:** 2
  - `POST form0969`
  - `GET form0969`

**Tests:** 11 total (0 request, 1 model, 0 service)

---

### income_limits

**Mount Path:** `/income_limits`

**Has Gemfile:** ✓

**Controllers:** 2
  - `application_controller` (0 actions)
  - `income_limits_controller` (15 actions)
    - Actions: index, validate_zip_code, valid_year, valid_dependents, calculate_pension_threshold, calculate_national_threshold, calculate_gmt_threshold, sanitized_zip_param, find_zipcode_data, find_income_threshold_data, find_county_data, find_gmt_threshold_data, render_invalid_year_error, render_invalid_dependents_error, render_zipcode_not_found_error

**Models:** 5
  - `gmt_threshold`
  - `std_county`
  - `std_income_threshold`
  - `std_state`
  - `std_zipcode`

**Routes:** 2
  - `GET limitsByZipCode/:zip/:year/:dependents`
  - `GET validateZipCode/:zip`

**Tests:** 3 total (2 request, 1 model, 0 service)

---

### increase_compensation

**Mount Path:** `/increase_compensation`

**Has Gemfile:** ✓

**Controllers:** 1
  - `claims_controller` (9 actions)
    - Actions: short_name, claim_class, show, create, check_flipper_flag, process_attachments, filtered_params, log_validation_error_to_metadata, monitor

**Models:** 2
  - `va_218940v1`
  - `saved_claim`

**Routes:** 2
  - `POST form8940`
  - `GET form8940/:id`

**Tests:** 13 total (0 request, 1 model, 0 service)

---

### ivc_champva

**Mount Path:** `/ivc_champva`

**Has Gemfile:** ✓

**Controllers:** 3
  - `application_controller` (0 actions)
  - `pega_controller` (9 actions)
    - Actions: update_status, update_data, get_ivc_forms, send_email, valid_keys, forms_query, fetch_forms_by_uuid, monitor, track_submit_to_callback_duration
  - `uploads_controller` (44 actions)
    - Actions: submit, validate_mpi_profiles, submit_champva_app_merged, handle_file_uploads_wrapper, should_generate_ves_json, generate_ves_json_file, prepare_ves_request, submit_ves_request, update_ves_records, call_handle_file_uploads, call_upload_form, unlock_file, unlock_with_pdftk, unlock_with_hexapdf, submit_supporting_documents, launch_background_job, launch_ocr_job, launch_llm_job, call_llm_service, tempfile_from_attachment, content_type_from_extension, applicants_with_ohi, generate_ohi_form, map_policies_to_applicant, map_primary_policy_to_applicant, map_secondary_policy_to_applicant, fill_ohi_and_return_path, create_custom_attachment, add_supporting_doc, log_error_and_respond, handle_file_uploads, upload_form, handle_file_uploads_with_refactored_retry, upload_form_with_refactored_retry, should_retry, get_attachment_ids_and_form, supporting_document_ids, build_attachment_ids, build_default_attachment_ids, add_blank_doc_and_stamp, get_file_paths_and_metadata, get_form_id, build_json, authenticate

**Services:** 19
  - `attachments`
  - `email`
  - `email_notification_callback`
  - `field_transliterator`
  - `file_uploader`
  - ...

**Models:** 9
  - `ves_request`
  - `vha_10_10d`
  - `vha_10_10d_2027`
  - `vha_10_7959a`
  - `vha_10_7959c`
  - ...

**Routes:** 4
  - `POST /forms`
  - `POST /forms/10-10d-ext`
  - `POST /forms/submit_supporting_documents`
  - `POST /forms/status_updates`

**Shared Concerns Used:**
  - `Vets::Model`

**Tests:** 50 total (7 request, 7 model, 18 service)

---

### meb_api

**Mount Path:** `/meb_api`

**Has Gemfile:** ✓

**Controllers:** 4
  - `apidocs_controller` (1 actions)
    - Actions: index
  - `base_controller` (5 actions)
    - Actions: authorize_access, check_forms_flipper, claim_status_service, claim_letters_service, claimant_service
  - `education_benefits_controller` (17 actions)
    - Actions: claimant_info, eligibility, claim_status, claim_letter, submit_claim, enrollment, send_confirmation_email, submit_enrollment_verification, duplicate_contact_info, exclusion_periods, set_type, contact_info_service, eligibility_service, automation_service, submission_service, enrollment_service, exclusion_period_service
  - `forms_controller` (14 actions)
    - Actions: claim_letter, claim_status, claimant_info, sponsors, submit_claim, send_confirmation_email, set_type, valid_claimant_response, render_claimant_error, determine_response_and_serializer, form_claimant_service, letter_service, sponsor_service, submission_service

**Routes:** 18
  - `GET claimant_info`
  - `GET service_history`
  - `GET eligibility`
  - `GET claim_status`
  - `GET claim_letter`
  - `POST submit_claim`
  - `GET enrollment`
  - `GET exclusion_periods`
  - `POST send_confirmation_email`
  - `POST submit_enrollment_verification`
  - ...

**Shared Concerns Used:**
  - `Vets::Model`
  - `Vets::SharedLogging`

**Tests:** 33 total (4 request, 0 model, 0 service)

---

### medical_expense_reports

**Mount Path:** `/medical_expense_reports`

**Has Gemfile:** ✓

**Controllers:** 1
  - `claims_controller` (14 actions)
    - Actions: short_name, claim_class, show, create, check_flipper_flag, process_attachments, filtered_params, log_validation_error_to_metadata, monitor, upload_to_s3, create_submission_attempt, s3_signed_url, last_form_submission_attempt, dated_directory_name

**Models:** 2
  - `va_21p8416`
  - `saved_claim`

**Routes:** 2
  - `POST form8416`
  - `GET form8416/:id`

**Tests:** 11 total (0 request, 1 model, 0 service)

---

### mobile

**Mount Path:** `/mobile`

**Has Gemfile:** ✓

**Controllers:** 65
  - `application_controller` (6 actions)
    - Actions: authenticate, sis_authentication, access_token, raise_unauthorized, session, set_sentry_tags_and_extra_context
  - `discovery_controller` (1 actions)
    - Actions: welcome
  - `messaging_controller` (7 actions)
    - Actions: client, authorize, raise_access_denied, authenticate_client, use_cache, pagination_params, mhv_messaging_authorized
  - `addresses_controller` (6 actions)
    - Actions: create, update, destroy, validate, address_params, validation_service
  - `allergy_intolerances_controller` (2 actions)
    - Actions: index, client
  - `appointments_controller` (19 actions)
    - Actions: index, cancel, create, build_page_metadata, validated_params, appointments_service, appointments_proxy, appointment_id, fetch_appointments, partial_errors, get_response_status, filter_by_date_range, paginate, include_pending, include_claims, upcoming_appointments_count, travel_pay_eligible_count, appointment_creator, staging_custom_error
  - `attachments_controller` (1 actions)
    - Actions: show
  - `authorized_services_controller` (3 actions)
    - Actions: index, user_accessible_services, get_metadata
  - `awards_controller` (2 actions)
    - Actions: index, regular_award_service
  - `cemeteries_controller` (2 actions)
    - Actions: index, client
  - `check_in_controller` (4 actions)
    - Actions: create, patient_dfn, chip_service, parse_error
  - `check_in_demographics_controller` (5 actions)
    - Actions: show, update, demographic_confirmations, patient_dfn, chip_service
  - `claims_and_appeals_controller` (29 actions)
    - Actions: index, get_claim, get_appeal, request_decision, upload_document, upload_multi_image_document, claim_letter_documents_search, claim_letter_document_download, set_params, tracked_item_id, file_name, prepare_claims_and_appeals, log_decision_letter_sent, fetch_claims_and_appeals, lighthouse_claims_adapter, appeal_adapter, claim_letter_documents_adapter, lighthouse_claims_proxy, claims_proxy, lighthouse_document_service, claims_index_interface, validated_params, paginate, pagination_params, get_response_status, filter_by_date, filter_by_completed, adapt_response, active_claims_count
  - `clinics_controller` (12 actions)
    - Actions: index, slots, facility_slots, render_facility_slots_error, systems_service, facility_id, service_type, clinic_id, provider_id, clinical_service, now, two_months_from_now
  - `community_care_eligibility_controller` (2 actions)
    - Actions: show, cce_service
  - `community_care_providers_controller` (7 actions)
    - Actions: index, ppms_api, locator_params, coordinates, facility_coordinates, pagination_params, paginate
  - `contact_info_controller` (1 actions)
    - Actions: show
  - `debts_controller` (3 actions)
    - Actions: index, show, service
  - `decision_letters_controller` (6 actions)
    - Actions: index, download, log_decision_letters, decision_letters_adapter, lighthouse_decision_letters_adapter, service
  - `demographics_controller` (3 actions)
    - Actions: index, raise_error, service
  - `dependents_controller` (4 actions)
    - Actions: index, create, dependent_params, dependent_service
  - `dependents_request_decisions_controller` (2 actions)
    - Actions: index, dependency_verification_service
  - `disability_rating_controller` (3 actions)
    - Actions: index, lighthouse_disability_rating_proxy, disability_rating_adapter
  - `efolder_controller` (5 actions)
    - Actions: index, download, service, file_name, efolder_adapter
  - `emails_controller` (4 actions)
    - Actions: create, update, destroy, email_params
  - `enrollment_status_controller` (3 actions)
    - Actions: show, authorize_user, validate_user_icn
  - `facilities_info_controller` (5 actions)
    - Actions: index, schedulable, validate_sort_method_inclusion, validate_home_sort, validate_current_location_sort
  - `facility_eligibility_controller` (7 actions)
    - Actions: index, patient_service, pagination_params, paginate, service_type, facility_ids, type
  - `feature_toggles_controller` (3 actions)
    - Actions: index, feature_toggles_service, set_current_user
  - `financial_status_reports_controller` (2 actions)
    - Actions: download, service
  - `folders_controller` (5 actions)
    - Actions: index, show, create, destroy, create_folder_params
  - `gender_identity_controller` (4 actions)
    - Actions: edit, update, service, gender_identity_params
  - `immunizations_controller` (3 actions)
    - Actions: index, immunizations_adapter, service
  - `labs_and_tests_controller` (2 actions)
    - Actions: index, client
  - `letters_controller` (15 actions)
    - Actions: index, beneficiary, download, get_coe_letter_type, download_lighthouse_letters, icn, validate_letter_type, validate_format, increment_download_counter, increment_coe_counter, download_options_hash, coe_app_version, letter_info_adapter, lighthouse_service, lgy_service
  - `locations_controller` (3 actions)
    - Actions: show, locations_adapter, service
  - `maintenance_windows_controller` (2 actions)
    - Actions: index, maintenance_windows
  - `medical_copays_controller` (6 actions)
    - Actions: index, show, download, statement_params, service, increment_pdf_statsd
  - `message_drafts_controller` (6 actions)
    - Actions: create, update, create_reply_draft, update_reply_draft, draft_params, reply_draft_params
  - `messages_controller` (17 actions)
    - Actions: index, show, create, destroy, thread, reply, categories, move, signature, message_params, upload_params, oh_triage_group, build_create_client_response, build_reply_client_response, message_counts, total_entries, extend_timeout
  - `military_information_controller` (5 actions)
    - Actions: get_service_history, user, military_info_adapter, service, log_service_indicator
  - `observations_controller` (2 actions)
    - Actions: show, client
  - `payment_history_controller` (8 actions)
    - Actions: index, validate_params, adapter, bgs_service_response, available_years, recurring_payment, filter, paginate
  - `payment_information_controller` (9 actions)
    - Actions: index, update, payment_information_params, pay_info, lighthouse_service, lighthouse_adapter, validate_pay_info, send_confirmation_email, validate_response
  - `pensions_controller` (2 actions)
    - Actions: index, pension_award_service
  - `phones_controller` (4 actions)
    - Actions: create, update, destroy, phone_params
  - `pre_need_burial_controller` (5 actions)
    - Actions: create, create_local_preneed_submission, burial_form_params, validate, client
  - `preferred_names_controller` (4 actions)
    - Actions: update, invalidate_mpi_cache, service, preferred_name_params
  - `prescriptions_controller` (13 actions)
    - Actions: index, refill, tracking, client, pagination_params, status_meta, paginate, filter_params, ids, resource_data_modifications, remove_pf_pd, remove_old_meds, non_va_meds
  - `profile_base_controller` (2 actions)
    - Actions: render_transaction_to_json, service
  - `push_notifications_controller` (6 actions)
    - Actions: register, get_prefs, set_pref, send_notification, service, get_app_name
  - `recipients_controller` (5 actions)
    - Actions: recipients, all_recipients, get_unique_care_systems, get_unique_care_systems612_fix, map_care_systems
  - `threads_controller` (1 actions)
    - Actions: index
  - `translations_controller` (4 actions)
    - Actions: download, file, file_md5, needs_translations
  - `travel_pay_claims_controller` (10 actions)
    - Actions: index, show, create, download_document, normalize_claim_summary, index_params, validated_params, auth_manager, smoc_service, claims_service
  - `users_controller` (7 actions)
    - Actions: show, logged_in, logout, options, map_logingov_to_idme, user_accessible_services, handle_vet360_id
  - `vet_verification_statuses_controller` (2 actions)
    - Actions: show, service
  - `veterans_affairs_eligibility_controller` (5 actions)
    - Actions: show, medical_service_adapter, mobile_facility_service, facility_ids, cc_supported_facility_ids
  - `allergy_intolerances_controller` (7 actions)
    - Actions: index, validate_feature_flag, pagination_contract, paginate_allergies, controller_enabled, routing_error, service
  - `immunizations_controller` (5 actions)
    - Actions: index, immunizations_adapter, service, pagination_params, immunizations
  - `labs_and_tests_controller` (4 actions)
    - Actions: index, controller_enabled, routing_error, service
  - `messages_controller` (2 actions)
    - Actions: thread, message_counts
  - `prescriptions_controller` (12 actions)
    - Actions: index, refill, unified_health_service, fetch_prescriptions, filtered_prescriptions, pagination_contract, paginate_prescriptions, build_meta, validate_feature_flag, status_meta, non_va_meds, orders
  - `users_controller` (4 actions)
    - Actions: show, options, user_accessible_services, handle_vet360_id
  - `users_controller` (1 actions)
    - Actions: show

**Services:** 16
  - `appointment_creator`
  - `proxy`
  - `proxy`
  - `claims_index_interface`
  - `proxy`
  - ...

**Models:** 92
  - `user`
  - `allergy_intolerance`
  - `appeal`
  - `check_in_demographics`
  - `check_in_update_demographics`
  - ...

**Routes:** 116
  - `GET /`
  - `GET /feature-toggles`
  - `GET /appeal/:id`
  - `GET /appointments`
  - `PUT /appointments/cancel/:id`
  - `GET /appointments/community_care/eligibility/:service_type`
  - `GET /appointments/va/eligibility`
  - `GET /appointments/facility/eligibility`
  - `GET /appointments/facilities/:facility_id/clinics`
  - `GET /appointments/facilities/:facility_id/clinics/:clinic_id/slots`
  - ...

**Shared Concerns Used:**
  - `Vets::Model`

**Tests:** 103 total (73 request, 11 model, 3 service)

---

### mocked_authentication

**Mount Path:** `/mocked_authentication`

**Has Gemfile:** ✓

**Controllers:** 3
  - `application_controller` (0 actions)
  - `credential_controller` (6 actions)
    - Actions: authorize, credential_list, index, validate_authorize_params, validate_index_params, validate_credential_list_params
  - `mockdata_controller` (3 actions)
    - Actions: show, mockdata_params, mockdata_authorize

**Services:** 2
  - `credential_info_creator`
  - `redirect_url_generator`

**Models:** 1
  - `credential_info`

**Routes:** 3
  - `GET /authorize`
  - `GET /credential_list`
  - `GET /profiles`

**Tests:** 10 total (2 request, 1 model, 2 service)

---

### my_health

**Mount Path:** `/my_health`

**Has Gemfile:** ✓

**Controllers:** 45
  - `apidocs_controller` (1 actions)
    - Actions: index
  - `application_controller` (0 actions)
  - `bb_controller` (3 actions)
    - Actions: client, authorize, raise_access_denied
  - `mr_controller` (10 actions)
    - Actions: with_patient_resource, render_resource, client, create_lighthouse_client, create_medical_records_client, phrmgr_client, bb_client, authenticate_bb_client, authorize, raise_access_denied
  - `rx_controller` (3 actions)
    - Actions: client, authorize, raise_access_denied
  - `sm_controller` (4 actions)
    - Actions: client, authorize, raise_access_denied, use_cache
  - `aal_controller` (3 actions)
    - Actions: create, aal_params, authorize_aal
  - `all_triage_teams_controller` (1 actions)
    - Actions: index
  - `allergies_controller` (2 actions)
    - Actions: index, show
  - `attachments_controller` (1 actions)
    - Actions: show
  - `clinical_notes_controller` (2 actions)
    - Actions: index, show
  - `conditions_controller` (2 actions)
    - Actions: index, show
  - `folders_controller` (8 actions)
    - Actions: index, show, create, update, destroy, search, create_folder_params, search_params
  - `health_record_contents_controller` (1 actions)
    - Actions: show
  - `health_records_controller` (7 actions)
    - Actions: refresh, eligible_data_classes, create, optin, optout, status, product
  - `labs_and_tests_controller` (2 actions)
    - Actions: index, show
  - `bbmi_notification_controller` (1 actions)
    - Actions: status
  - `ccd_controller` (7 actions)
    - Actions: generate, download, product, deliver_ccd, requested_format, handle_aal_action, log_aal_action
  - `imaging_controller` (10 actions)
    - Actions: index, request_download, request_status, images, image, dicom, set_study_id, render_resource, header_callback, stream_data
  - `military_service_controller` (5 actions)
    - Actions: index, client, authorize, raise_access_denied, product
  - `mr_session_controller` (2 actions)
    - Actions: create, status
  - `patient_controller` (2 actions)
    - Actions: index, demographic
  - `radiology_controller` (1 actions)
    - Actions: index
  - `self_entered_controller` (19 actions)
    - Actions: index, vitals, allergies, family_history, vaccines, test_entries, medical_events, military_history, providers, health_insurance, treatment_facilities, food_journal, activity_journal, medications, emergency_contacts, client, authorize, raise_access_denied, product
  - `message_drafts_controller` (6 actions)
    - Actions: create, update, create_reply_draft, update_reply_draft, draft_params, reply_draft_params
  - `messages_controller` (20 actions)
    - Actions: show, create, destroy, thread, reply, categories, signature, move, prepare_message_params_h, build_response_options, create_client_response, reply_client_response, message_params, upload_params, oh_triage_group, any_file_too_large, total_size_too_large, total_file_count_too_large, use_large_attachment_upload, extend_timeout
  - `messaging_preferences_controller` (6 actions)
    - Actions: show, update, update_triage_team_preferences, signature, update_signature, render_signature
  - `prescription_documentation_controller` (1 actions)
    - Actions: index
  - `prescription_preferences_controller` (2 actions)
    - Actions: show, update
  - `prescriptions_controller` (20 actions)
    - Actions: index, show, refill, filter_renewals, refill_prescriptions, list_refillable_prescriptions, get_prescription_image, get_recently_requested_prescriptions, fetch_and_include_images, fetch_image, get_image_uri, filter_params, apply_filters, collection_resource, resource_data_modifications, set_filter_metadata, count_active_medications, count_non_active_medications, remove_pf_pd, sort_prescriptions_with_pd_at_top
  - `threads_controller` (4 actions)
    - Actions: index, move, fetch_folder_threads, handle_error
  - `tooltips_controller` (8 actions)
    - Actions: index, create, update, log_and_render_error, set_tooltip, tooltip_params, increment_counter_if_new_session, set_user_account
  - `trackings_controller` (1 actions)
    - Actions: index
  - `triage_teams_controller` (1 actions)
    - Actions: index
  - `unique_user_metrics_controller` (3 actions)
    - Actions: create, metrics_params, authenticate
  - `vaccines_controller` (2 actions)
    - Actions: index, show
  - `vitals_controller` (1 actions)
    - Actions: index
  - `allergies_controller` (3 actions)
    - Actions: index, show, service
  - `ccd_controller` (2 actions)
    - Actions: download, service
  - `clinical_notes_controller` (3 actions)
    - Actions: index, show, service
  - `conditions_controller` (3 actions)
    - Actions: index, show, service
  - `immunizations_controller` (3 actions)
    - Actions: index, show, client
  - `labs_and_tests_controller` (2 actions)
    - Actions: index, service
  - `prescriptions_controller` (20 actions)
    - Actions: refill, index, show, list_refillable_prescriptions, service, validate_feature_flag, apply_filters_and_sorting, build_response_data, build_paginated_response, log_prescriptions_access, get_recently_requested_prescriptions, apply_filters_to_list, apply_sorting_to_list, resource_data_modifications, set_filter_metadata, count_active_medications, count_non_active_medications, remove_pf_pd, sort_prescriptions_with_pd_at_top, orders
  - `vitals_controller` (2 actions)
    - Actions: index, service

**Routes:** 12
  - `GET ccd/download(.:format)`
  - `GET download(.:format)`
  - `GET request`
  - `GET images/:series_id/:image_id`
  - `POST :reply_id/replydraft`
  - `PUT :reply_id/replydraft/:draft_id`
  - `POST recipients`
  - `GET get_prescription_image/:cmopNdcNumber`
  - `POST sharing/optin`
  - `POST sharing/optout`
  - ...

**Shared Concerns Used:**
  - `Vets::SharedLogging`

**Tests:** 53 total (33 request, 0 model, 0 service)

---

### pensions

**Mount Path:** `/pensions`

**Has Gemfile:** ✓

**Controllers:** 1
  - `claims_controller` (15 actions)
    - Actions: short_name, claim_class, show, create, create_claim, submit_traceability_to_event_bus, process_attachments, process_and_upload_to_bpds, get_user_identifier_for_bpds, get_participant_id_or_file_number_from_bgs, filtered_params, log_validation_error_to_metadata, sanitize_attachments, monitor, bpds_monitor

**Models:** 3
  - `form_military_information`
  - `va_21p527ez`
  - `saved_claim`

**Shared Concerns Used:**
  - `Vets::Model`

**Tests:** 18 total (0 request, 1 model, 0 service)

---

### representation_management

**Mount Path:** `/representation_management`

**Has Gemfile:** ✓

**Controllers:** 11
  - `accredited_entities_for_appoint_controller` (3 actions)
    - Actions: index, feature_enabled, current_data_source_log
  - `accredited_individuals_controller` (23 actions)
    - Actions: index, base_query, distance_query, individual_query, search_params, pagination_params, sort_param, type_param, select_query_string, distance_query_string, sort_query_string, distance_asc_string, max_distance, feature_enabled, current_data_source_log, use_veteran_model, determine_model_class, where_clause_for_veteran_type, select_query_string_for_veteran, distance_query_string_for_veteran, sort_query_string_for_veteran, distance_asc_string_for_veteran, find_veteran_with_name_similar_to
  - `apidocs_controller` (1 actions)
    - Actions: index
  - `flag_accredited_representatives_controller` (3 actions)
    - Actions: create, create_flags, feature_enabled
  - `next_steps_email_controller` (7 actions)
    - Actions: create, email_personalisation, feature_enabled, email_callback_options, email_delivery_callback, next_steps_email_params, template_id
  - `original_entities_controller` (2 actions)
    - Actions: index, feature_enabled
  - `pdf_generator_2122_controller` (3 actions)
    - Actions: create, form_params, flatten_form_params
  - `pdf_generator_2122a_controller` (4 actions)
    - Actions: create, form_params, flatten_form_params, flatten_veteran_params
  - `power_of_attorney_controller` (9 actions)
    - Actions: index, lighthouse_service, icn, poa_code, poa_type, record, serializer, organization, representative
  - `power_of_attorney_request_base_controller` (10 actions)
    - Actions: params_permitted, claimant_params_permitted, representative_params_permitted, veteran_params_permitted, flatten_claimant_params, flatten_veteran_params, name_params_permitted, address_params_permitted, normalize_country_code_to_alpha2, feature_enabled
  - `power_of_attorney_requests_controller` (9 actions)
    - Actions: create, feature_enabled, form_params, flatten_form_params, dependent, service_branch, consent_limits, form, orchestrate_response

**Services:** 6
  - `accredited_entity_query`
  - `address_validation_service`
  - `client`
  - `configuration`
  - `original_entity_query`
  - ...

**Models:** 9
  - `accreditation_api_entity_count`
  - `accreditation_data_ingestion_log`
  - `accredited_individual_search`
  - `flagged_veteran_representative_contact_data`
  - `form_2122_base`
  - ...

**Routes:** 1
  - `GET apidocs`

**Tests:** 48 total (17 request, 9 model, 6 service)

---

### simple_forms_api

**Mount Path:** `/simple_forms_api`

**Has Gemfile:** ✓

**Controllers:** 4
  - `application_controller` (0 actions)
  - `cemeteries_controller` (2 actions)
    - Actions: index, format_cemetery
  - `scanned_form_uploads_controller` (20 actions)
    - Actions: submit, upload_scanned_form, upload_supporting_documents, lighthouse_service, upload_response, upload_response_legacy, upload_response_with_supporting_documents, find_attachment_path, validated_metadata, upload_pdf, prepare_for_upload, create_form_submission_attempt, create_form_submission, log_upload_details, perform_pdf_upload, check_for_changes, send_confirmation_email, extract_uploaded_file, valid_uploaded_file, render_upload_error
  - `uploads_controller` (31 actions)
    - Actions: submit, submit_supporting_documents, get_intents_to_file, validate_document_if_needed, lighthouse_service, skip_authentication, intent_service, handle_210966_authenticated, handle264555, submit_form_to_benefits_intake, build_response, get_file_paths_and_metadata, upload_pdf, prepare_for_upload, stamp_pdf_with_uuid, create_form_submission_attempt, create_form_submission, log_upload_details, perform_pdf_upload, upload_pdf_to_s3, form_is264555_and_should_use_lgy_api, icn, form_id, get_json, prepare_params_for_benefits_intake_and_log_error, json_for210966, send_confirmation_email, send_intent_received_email, send_sahsha_email, send_confirmation_email_safely, add_vsi_flash_safely

**Services:** 19
  - `cemetery_service`
  - `file_utilities`
  - `form0781_submission_remediation_data`
  - `form526_submission_archive`
  - `archive_batch_processing_job`
  - ...

**Models:** 21
  - `address`
  - `employment_history`
  - `base_form`
  - `vba_20_10206`
  - `vba_20_10207`
  - ...

**Routes:** 6
  - `POST /simple_forms`
  - `POST /simple_forms/submit_supporting_documents`
  - `GET /simple_forms/get_intents_to_file`
  - `POST /submit_scanned_form`
  - `POST /scanned_form_upload`
  - `POST /supporting_documents_upload`

**Shared Concerns Used:**
  - `Vets::Model`

**Tests:** 42 total (3 request, 19 model, 17 service)

---

### sob

**Mount Path:** `/sob`

**Has Gemfile:** ✓

**Controllers:** 1
  - `ch33_statuses_controller` (2 actions)
    - Actions: show, service

**Services:** 3
  - `configuration`
  - `response`
  - `service`

**Models:** 1
  - `entitlement`

**Shared Concerns Used:**
  - `Vets::Model`

**Tests:** 5 total (1 request, 0 model, 3 service)

---

### survivors_benefits

**Mount Path:** `/survivors_benefits`

**Has Gemfile:** ✓

**Controllers:** 1
  - `claims_controller` (11 actions)
    - Actions: short_name, claim_class, show, create, check_flipper_flag, process_attachments, filtered_params, log_validation_error_to_metadata, monitor, config, pdf_url

**Models:** 2
  - `va_21p534ez`
  - `saved_claim`

**Routes:** 2
  - `POST form534ez`
  - `GET form534ez/:id`

**Tests:** 11 total (0 request, 1 model, 0 service)

---

### test_user_dashboard

**Mount Path:** `/test_user_dashboard`

**Has Gemfile:** ✓

**Controllers:** 3
  - `application_controller` (3 actions)
    - Actions: require_jwt, valid_token, set_sentry_tags_and_extra_context
  - `tud_accounts_controller` (2 actions)
    - Actions: index, update
  - `tud_github_oauth_proxy_controller` (2 actions)
    - Actions: index, github_oauth_access_token_request

**Services:** 3
  - `account_metrics`
  - `create_test_user_account`
  - `update_user`

**Models:** 2
  - `tud_account`
  - `tud_account_availability_log`

**Shared Concerns Used:**
  - `Vets::SharedLogging`

**Tests:** 7 total (2 request, 1 model, 3 service)

---

### travel_claims

**Mount Path:** `NOT MOUNTED`

**Has Gemfile:** ✓

**Tests:** 1 total (0 request, 0 model, 0 service)

---

### travel_pay

**Mount Path:** `/travel_pay`

**Has Gemfile:** ✓

**Controllers:** 5
  - `application_controller` (4 actions)
    - Actions: before_logger, after_logger, block_if_flag_disabled, raise_access_denied
  - `claims_controller` (9 actions)
    - Actions: index, show, create, auth_manager, claims_service, appts_service, expense_service, scrub_logs, handle_resource_not_found_error
  - `complex_claims_controller` (6 actions)
    - Actions: submit, create, handle_faraday_error, check_feature_flag, render_bad_request, validate_datetime_format
  - `documents_controller` (10 actions)
    - Actions: show, create, destroy, handle_faraday_error, check_feature_flag, render_bad_request, auth_manager, service, handle_resource_not_found_error, validate_document_exists
  - `expenses_controller` (17 actions)
    - Actions: show, create, update, destroy, auth_manager, expense_service, check_feature_flag, create_and_validate_expense, validate_claim_id, validate_expense_id, validate_expense_type, validate_expense_id, valid_expense_types, build_expense_from_params, expense_class_for_type, permitted_params, expense_params_for_service

**Services:** 19
  - `appointments_client`
  - `appointments_service`
  - `auth_manager`
  - `base_client`
  - `claim_association_service`
  - ...

**Models:** 9
  - `base_expense`
  - `common_carrier_expense`
  - `flight_expense`
  - `lodging_expense`
  - `meal_expense`
  - ...

**Routes:** 4
  - `POST expenses/:expense_type`
  - `GET expenses/:expense_type/:expense_id`
  - `DELETE expenses/:expense_type/:expense_id`
  - `PATCH expenses/:expense_type/:expense_id`

**Tests:** 34 total (8 request, 8 model, 17 service)

---

### va_notify

**Mount Path:** `/va_notify`

**Has Gemfile:** ✓

**Controllers:** 2
  - `application_controller` (0 actions)
  - `callbacks_controller` (10 actions)
    - Actions: create, set_notification, authenticate_callback, authenticate_signature, authenticate_token, authenticity_error, bearer_token_secret, service_callback_tokens, notification_params, get_api_key_value

**Services:** 3
  - `custom_callback`
  - `find_in_progress_forms`
  - `in_progress_form_reminder`

**Models:** 4
  - `confirmation_email`
  - `in_progress_reminders_sent`
  - `notification`
  - `veteran`

**Routes:** 1
  - `POST /callbacks`

**Shared Concerns Used:**
  - `Vets::SharedLogging`

**Tests:** 20 total (1 request, 2 model, 3 service)

---

### vaos

**Mount Path:** `/vaos`

**Has Gemfile:** ✓

**Controllers:** 13
  - `base_controller` (1 actions)
    - Actions: set_controller_name_for_logging
  - `apidocs_controller` (1 actions)
    - Actions: index
  - `appointments_controller` (50 actions)
    - Actions: index, show, create, create_draft, update, submit_referral_appointment, set_facility_error_msg, appointments_service, mobile_facility_service, eps_appointment_service, eps_provider_service, appointments, vaos_appointment, eps_appointment, new_appointment, updated_appointment, get_new_appointment, scrape_appt_comments_and_log_details, log_appt_comment_data, log_appt_creation_time, appt_comment_log_details, update_appt_id, status_update, appointment_index_params, appointment_show_params, draft_params, create_params, start_date, end_date, include_index_params, include_show_params, statuses, appointment_id, index_method_logging_name, show_method_logging_name, create_method_logging_name, submit_params, submit_address_params, patient_attributes, handle_redis_error, ccra_referral_service, appointment_error_status, handle_appointment_creation_error, appt_creation_failed_error, submission_error_response, log_referral_booking_duration, build_submit_args, record_appt_metric, get_type_of_care_for_metrics, sanitize_log_value
  - `cc_eligibility_controller` (2 actions)
    - Actions: show, cce_service
  - `clinics_controller` (11 actions)
    - Actions: index, last_visited_clinic, appointments_service, filter_type_of_care_facilities, log_unable_to_lookup_clinic, log_no_clinic_details_found, unable_to_lookup_clinic, log_no_supported_facilities, systems_service, mobile_facility_service, location_id
  - `eps_appointments_controller` (8 actions)
    - Actions: show, assemble_appt_response_object, fetch_provider, eps_appointment_id, vaos_serializer, provider_service, appointment_service, provider
  - `facilities_controller` (12 actions)
    - Actions: index, show, sort_by_recent_facilities, mobile_facility_service, appointments_service, location_id_available, facility, facility_id, ids, children, type, schedulable
  - `patients_controller` (3 actions)
    - Actions: index, patient_service, patient_params
  - `providers_controller` (4 actions)
    - Actions: show, vaos_serializer, provider_service, provider
  - `referrals_controller` (13 actions)
    - Actions: index, show, add_appointment_data_to_referral, appointments_service, log_referral_count, add_referral_uuids, referral_uuid, referral_status_param, filter_expired_referrals, referral_service, sanitize_log_value, log_referral_metrics, log_missing_provider_ids
  - `relationships_controller` (3 actions)
    - Actions: index, relationships_service, relationships_params
  - `scheduling_controller` (3 actions)
    - Actions: configurations, mobile_facility_service, csv_facility_ids
  - `slots_controller` (10 actions)
    - Actions: index, facility_slots, systems_service, facility_slots_bad_request, location_id, clinic_id, provider_id, clinical_service, start_dt, end_dt

**Services:** 34
  - `base_service`
  - `redis_client`
  - `referral_service`
  - `jwt_wrapper`
  - `base_logging`
  - ...

**Models:** 7
  - `referral_detail`
  - `referral_list_entry`
  - `preference_form`
  - `session_store`
  - `appointment_form`
  - ...

**Routes:** 22
  - `GET apidocs`
  - `GET /appointments`
  - `GET /appointments/:appointment_id`
  - `PUT /appointments/:id`
  - `GET /eps_appointments/:id`
  - `GET /providers`
  - `GET /providers/:provider_id`
  - `GET community_care/eligibility/:service_type`
  - `GET /locations/:location_id/clinics`
  - `GET /locations/last_visited_clinic`
  - ...

**Shared Concerns Used:**
  - `Vets::Model`
  - `Vets::SharedLogging`

**Tests:** 68 total (11 request, 5 model, 35 service)

---

### vass

**Mount Path:** `/vass`

**Has Gemfile:** ✓

**Controllers:** 1
  - `application_controller` (9 actions)
    - Actions: cors_preflight, handle_authentication_error, handle_not_found_error, handle_validation_error, handle_service_error, handle_vass_api_error, handle_redis_error, log_safe_error, render_error_response

**Services:** 4
  - `appointments_service`
  - `client`
  - `configuration`
  - `redis_client`

**Routes:** 1
  - `GET apidocs`

**Tests:** 5 total (0 request, 0 model, 3 service)

---

### vba_documents

**Mount Path:** `NOT MOUNTED`

**Has Gemfile:** ✓

**Controllers:** 6
  - `application_controller` (3 actions)
    - Actions: require_gateway_origin, set_extra_context, consumer
  - `api_controller` (1 actions)
    - Actions: index
  - `upload_complete_controller` (8 actions)
    - Actions: create, verify_topic_arn, verify_message, json_params, json_message, read_body, process_upload, log_details
  - `metadata_controller` (6 actions)
    - Actions: index, benefits_intake_v1, healthcheck, s3_is_healthy, upstream_healthcheck, upstream_service_details
  - `reports_controller` (3 actions)
    - Actions: create, with_spoofed, validate_params
  - `uploads_controller` (7 actions)
    - Actions: show, create, download, validate_document, verify_download_enabled, verify_validate_enabled, render_not_found

**Services:** 2
  - `hash_notification`
  - `messenger`

**Models:** 3
  - `monthly_stat`
  - `upload_file`
  - `upload_submission`

**Routes:** 5
  - `GET /metadata`
  - `GET /v1/healthcheck`
  - `GET /v1/upstream_healthcheck`
  - `POST /uploads/validate_document`
  - `GET download`

**Tests:** 35 total (6 request, 3 model, 2 service)

---

### veteran

**Mount Path:** `/veteran`

**Has Gemfile:** ✓

**Controllers:** 5
  - `apidocs_controller` (1 actions)
    - Actions: index
  - `base_accredited_representatives_controller` (14 actions)
    - Actions: index, serializer_class, base_query, search_params, pagination_params, sort_param, distance_query_string, sort_query_string, max_distance, feature_enabled, verify_sort, verify_long, verify_lat, verify_distance
  - `other_accredited_representatives_controller` (4 actions)
    - Actions: serializer_class, representative_query, find_with_name_similar_to, verify_type
  - `representatives_controller` (3 actions)
    - Actions: find_rep, check_required_fields, error_hash
  - `vso_accredited_representatives_controller` (4 actions)
    - Actions: serializer_class, representative_query, find_with_name_similar_to, verify_type

**Services:** 1
  - `address_preprocessor`

**Models:** 6
  - `accreditation_total`
  - `base`
  - `constants`
  - `organization`
  - `representative`
  - ...

**Routes:** 2
  - `GET representatives/find_rep`
  - `GET apidocs`

**Shared Concerns Used:**
  - `Vets::Model`
  - `Vets::SharedLogging`

**Tests:** 27 total (6 request, 4 model, 1 service)

---

### vre

**Mount Path:** `/vre`

**Has Gemfile:** ✓

**Controllers:** 2
  - `ch31_eligibility_statuses_controller` (2 actions)
    - Actions: show, eligibility_service
  - `claims_controller` (4 actions)
    - Actions: create, filtered_params, short_name, encrypted_user

**Services:** 6
  - `configuration`
  - `response`
  - `service`
  - `ch31_form`
  - `configuration`
  - ...

**Models:** 8
  - `disability_rating`
  - `entitlement`
  - `entitlement_details`
  - `scd_detail`
  - `service_period`
  - ...

**Shared Concerns Used:**
  - `Vets::Model`
  - `Vets::SharedLogging`

**Tests:** 13 total (1 request, 1 model, 4 service)

---

### vye

**Mount Path:** `/vye`

**Has Gemfile:** ✓

**Controllers:** 1
  - `dgib_verifications_controller` (6 actions)
    - Actions: verification_record, verify_claimant, claimant_status, claimant_lookup, service, process_response

**Routes:** 4
  - `POST dgib_verifications/verification_record`
  - `POST dgib_verifications/verify_claimant`
  - `POST dgib_verifications/claimant_status`
  - `GET dgib_verifications/claimant_lookup`

**Tests:** 2 total (0 request, 0 model, 0 service)

---
