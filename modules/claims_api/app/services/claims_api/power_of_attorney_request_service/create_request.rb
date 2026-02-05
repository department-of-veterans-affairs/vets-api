# frozen_string_literal: true

require 'bgs_service/veteran_representative_service'
require 'bgs_service/vnp_person_service'
require 'bgs_service/vnp_proc_form_service'
require 'bgs_service/vnp_proc_service_v2'
require 'bgs_service/vnp_ptcpnt_addrs_service'
require 'bgs_service/vnp_ptcpnt_phone_service'
require 'bgs_service/vnp_ptcpnt_service'
require 'concurrent-ruby'
require 'brd/brd'

module ClaimsApi
  module PowerOfAttorneyRequestService
    class CreateRequest
      FORM_TYPE = '21-22'
      PHONE_TYPE = 'Daytime'
      PTCPNT_TYPE = 'Person'
      REPRESENTATIVE_TYPE = 'Recognized Veterans Service Organization'
      VDC_STATUS = 'SUBMITTED'

      def initialize(veteran_participant_id, form_data, claimant_participant_id = nil)
        @veteran_participant_id = veteran_participant_id
        @form_data = form_data
        @claimant_participant_id = claimant_participant_id
        @has_claimant = claimant_participant_id.present?
        @poa_key = :poa
      end

      def call
        # https://github.com/DataDog/dd-trace-rb/blob/master/docs/UpgradeGuide.md#distributed-tracing
        trace_digest = Datadog::Tracing.active_trace&.to_digest

        @vnp_proc_id = create_vnp_proc[:vnp_proc_id]

        # Parallelize create_vnp_form and create_vnp_ptcpnt
        form_promise = Concurrent::Promise.execute do
          Datadog::Tracing.continue_trace!(trace_digest) do
            create_vnp_form
          end
        end

        ptcpnt_promise = Concurrent::Promise.execute do
          Datadog::Tracing.continue_trace!(trace_digest) do
            create_vnp_ptcpnt(@veteran_participant_id)
          end
        end

        # Wait for both promises and store the participant ID
        form_promise.value!
        @veteran_vnp_ptcpnt_id = ptcpnt_promise.value![:vnp_ptcpnt_id]

        create_vonapp_data(@form_data[:veteran], @veteran_vnp_ptcpnt_id, trace_digest, 'veteran')

        create_claimant(trace_digest) if @has_claimant

        veteran_rep_obj = create_veteran_representative
        add_meta_ids(veteran_rep_obj)
      end

      private

      def create_vonapp_data(person, vnp_ptcpnt_id, trace_digest, type) # rubocop:disable Metrics/MethodLength
        promises = []
        @vnp_res_object ||= { 'meta' => {} }
        @vnp_res_object['meta'][type] ||= {}

        promises << Concurrent::Promise.execute do
          Datadog::Tracing.continue_trace!(trace_digest) do
            create_vnp_person(person, vnp_ptcpnt_id)
          end
        end

        promises << Concurrent::Promise.execute do
          Datadog::Tracing.continue_trace!(trace_digest) do
            res = create_vnp_mailing_address(person[:address], vnp_ptcpnt_id)
            @vnp_res_object['meta'][type.to_s]['vnp_mail_id'] = res[:vnp_ptcpnt_addrs_id] if res
          end
        end

        if person[:email]
          promises << Concurrent::Promise.execute do
            Datadog::Tracing.continue_trace!(trace_digest) do
              res = create_vnp_email_address(person[:email], vnp_ptcpnt_id)
              # Save this data in a separate vnp_ptcpnt_addrs_id record
              @vnp_res_object['meta'][type.to_s]['vnp_email_id'] = res[:vnp_ptcpnt_addrs_id] if res
            end
          end
        end

        if person[:phone]
          promises << Concurrent::Promise.execute do
            Datadog::Tracing.continue_trace!(trace_digest) do
              res = create_vnp_phone(person[:phone], vnp_ptcpnt_id)
              if res
                @vnp_res_object['meta'][type.to_s]['vnp_phone_id'] = res[:vnp_ptcpnt_phone_id]

                @vnp_res_object['meta'][type.to_s]['phone_data'] = {}
                phone_data = person[:phone].slice(:countryCode, :areaCode, :phoneNumber).transform_keys(&:to_s)
                phone_data['phoneNumber'] = phone_data['phoneNumber']&.gsub(/\s/, '')
                @vnp_res_object['meta'][type.to_s]['phone_data'] = phone_data
              end
            end
          end
        end

        # Wait for all promises to complete and raise any errors that occurred
        promises.each(&:value!)
      end

      def create_claimant(trace_digest)
        @claimant_vnp_ptcpnt_id = create_vnp_ptcpnt(@claimant_participant_id)[:vnp_ptcpnt_id]
        create_vonapp_data(@form_data[:claimant], @claimant_vnp_ptcpnt_id, trace_digest, 'claimant')
      end

      def create_vnp_proc
        ClaimsApi::VnpProcServiceV2
          .new(external_uid: @veteran_participant_id, external_key: @veteran_participant_id)
          .vnp_proc_create
      end

      def create_vnp_form
        ClaimsApi::VnpProcFormService
          .new(external_uid: @veteran_participant_id, external_key: @veteran_participant_id)
          .vnp_proc_form_create(
            {
              vnp_proc_id: @vnp_proc_id,
              vnp_ptcpnt_id: nil
            }
          )
      end

      def create_vnp_ptcpnt(participant_id)
        vnp_ptcpnt_service.vnp_ptcpnt_create(
          {
            vnp_proc_id: @vnp_proc_id,
            vnp_ptcpnt_id: nil,
            fraud_ind: nil,
            legacy_poa_cd: nil,
            misc_vendor_ind: nil,
            ptcpnt_short_nm: nil,
            ptcpnt_type_nm: PTCPNT_TYPE,
            tax_idfctn_nbr: nil,
            tin_waiver_reason_type_cd: nil,
            ptcpnt_fk_ptcpnt_id: nil,
            corp_ptcpnt_id: participant_id
          }
        )
      end

      def create_vnp_person(person, vnp_ptcpnt_id)
        ClaimsApi::VnpPersonService
          .new(external_uid: @veteran_participant_id, external_key: @veteran_participant_id)
          .vnp_person_create(
            {
              vnp_proc_id: @vnp_proc_id,
              vnp_ptcpnt_id:,
              first_nm: person[:firstName],
              last_nm: person[:lastName],
              brthdy_dt: person[:birthdate],
              ssn_nbr: person[:ssn],
              file_nbr: person[:va_file_number],
              person_type_nm: 'Veteran'
            }
          )
      end

      # rubocop: disable Metrics/MethodLength
      def create_vnp_mailing_address(address, vnp_ptcpnt_id)
        vnp_ptcpnt_addrs_service
          .vnp_ptcpnt_addrs_create(
            {
              vnp_ptcpnt_addrs_id: nil,
              vnp_proc_id: @vnp_proc_id,
              vnp_ptcpnt_id:,
              efctv_dt: Time.current.iso8601,
              addrs_one_txt: address[:addressLine1],
              addrs_three_txt: nil,
              addrs_two_txt: address[:addressLine2],
              bad_addrs_ind: nil,
              city_nm: address[:city],
              cntry_nm: ClaimsApi::BRD::COUNTRY_CODES[address[:countryCode].to_s.upcase],
              county_nm: nil,
              eft_waiver_type_nm: nil,
              email_addrs_txt: nil,
              end_dt: nil,
              fms_addrs_code_txt: nil,
              frgn_postal_cd: nil,
              group_1_verifd_type_cd: nil,
              lctn_nm: nil,
              mlty_postal_type_cd: nil,
              mlty_post_office_type_cd: nil,
              postal_cd: address[:stateCode],
              prvnc_nm: nil,
              ptcpnt_addrs_type_nm: 'Mailing',
              shared_addrs_ind: 'N',
              trsury_addrs_five_txt: nil,
              trsury_addrs_four_txt: nil,
              trsury_addrs_one_txt: nil,
              trsury_addrs_six_txt: nil,
              trsury_addrs_three_txt: nil,
              trsury_addrs_two_txt: nil,
              trsury_seq_nbr: nil,
              trtry_nm: nil,
              zip_first_suffix_nbr: address[:zipCodeSuffix],
              zip_prefix_nbr: address[:zipCode],
              zip_second_suffix_nbr: nil
            }
          )
      end
      # rubocop: enable Metrics/MethodLength

      # rubocop: disable Metrics/MethodLength
      def create_vnp_email_address(email, vnp_ptcpnt_id)
        vnp_ptcpnt_addrs_service
          .vnp_ptcpnt_addrs_create(
            {
              vnp_ptcpnt_addrs_id: nil,
              vnp_proc_id: @vnp_proc_id,
              vnp_ptcpnt_id:,
              efctv_dt: Time.current.iso8601,
              addrs_one_txt: nil,
              addrs_three_txt: nil,
              addrs_two_txt: nil,
              bad_addrs_ind: nil,
              city_nm: nil,
              cntry_nm: nil,
              county_nm: nil,
              eft_waiver_type_nm: nil,
              email_addrs_txt: email,
              end_dt: nil,
              fms_addrs_code_txt: nil,
              frgn_postal_cd: nil,
              group_1_verifd_type_cd: nil,
              lctn_nm: nil,
              mlty_postal_type_cd: nil,
              mlty_post_office_type_cd: nil,
              postal_cd: nil,
              prvnc_nm: nil,
              ptcpnt_addrs_type_nm: 'Email',
              shared_addrs_ind: 'N',
              trsury_addrs_five_txt: nil,
              trsury_addrs_four_txt: nil,
              trsury_addrs_one_txt: nil,
              trsury_addrs_six_txt: nil,
              trsury_addrs_three_txt: nil,
              trsury_addrs_two_txt: nil,
              trsury_seq_nbr: nil,
              trtry_nm: nil,
              zip_first_suffix_nbr: nil,
              zip_prefix_nbr: nil,
              zip_second_suffix_nbr: nil
            }
          )
      end
      # rubocop: enable Metrics/MethodLength

      def create_vnp_phone(phone_data, vnp_ptcpnt_id)
        ClaimsApi::VnpPtcpntPhoneService
          .new(external_uid: @veteran_participant_id, external_key: @veteran_participant_id)
          .vnp_ptcpnt_phone_create(
            {
              vnp_proc_id: @vnp_proc_id,
              vnp_ptcpnt_id:,
              phone_type_nm: PHONE_TYPE,
              phone_nbr: parse_phone_data(phone_data, 'domestic'),
              cntry_nbr: phone_data[:countryCode].to_s,
              frgn_phone_rfrnc_txt: parse_phone_data(phone_data, 'international'),
              efctv_dt: Time.current.iso8601
            }
          )
      end

      # rubocop: disable Metrics/MethodLength
      # rubocop: disable Naming/VariableNumber
      def create_veteran_representative
        ClaimsApi::VeteranRepresentativeService
          .new(external_uid: @veteran_participant_id, external_key: @veteran_participant_id)
          .create_veteran_representative(
            {
              address_line_1: @form_data[:veteran][:address][:addressLine1],
              address_line_2: @form_data[:veteran][:address][:addressLine2],
              change_address_auth: @form_data[:consentAddressChange],
              city: @form_data[:veteran][:address][:city],
              claimant_ptcpnt_id: @has_claimant ? @claimant_vnp_ptcpnt_id : @veteran_vnp_ptcpnt_id,
              claimant_relationship: @has_claimant ? @form_data[:claimant][:relationship] : nil,
              form_type_code: FORM_TYPE,
              insurance_numbers: @form_data.dig(:veteran, :insuranceNumber),
              limitation_alcohol: limitation?('ALCOHOLISM'),
              limitation_drug_abuse: limitation?('DRUG_ABUSE'),
              limitation_h_i_v: limitation?('HIV'),
              limitation_s_c_a: limitation?('SICKLE_CELL'),
              organization_name: @form_data.dig(@poa_key, :organizationName),
              other_service_branch: @form_data.dig(:veteran, :serviceBranchOther),
              phone_number: parse_phone_data(@form_data.dig(:veteran, :phone), 'domestic'),
              cntry_nbr: @form_data.dig(:veteran, :phone, :countryCode),
              frgn_phone_rfrnc_txt: parse_phone_data(@form_data.dig(:veteran, :phone), 'international'),
              poa_code: @form_data.dig(:representative, :poaCode),
              postal_code: @form_data[:veteran][:address][:zipCode],
              proc_id: @vnp_proc_id,
              representative_first_name: @form_data.dig(@poa_key, :firstName),
              representative_last_name: @form_data.dig(@poa_key, :lastName),
              representative_title: @form_data.dig(@poa_key, :jobTitle),
              representative_type: REPRESENTATIVE_TYPE,
              section_7332_auth: @form_data[:recordConsent],
              service_branch: @form_data.dig(:veteran, :serviceBranch)&.titlecase,
              service_number: @form_data[:veteran][:serviceNumber],
              state: @form_data[:veteran][:address][:stateCode],
              submitted_date: Time.current.iso8601,
              vdc_status: VDC_STATUS,
              veteran_ptcpnt_id: @veteran_vnp_ptcpnt_id
            }
          )
      end
      # rubocop: enable Metrics/MethodLength
      # rubocop: enable Naming/VariableNumber

      def vnp_ptcpnt_service
        @vnp_ptcpnt_service ||= ClaimsApi::VnpPtcpntService
                                .new(external_uid: @veteran_participant_id, external_key: @veteran_participant_id)
      end

      def vnp_ptcpnt_addrs_service
        @vnp_ptcpnt_addrs_service ||= ClaimsApi::VnpPtcpntAddrsService
                                      .new(external_uid: @veteran_participant_id, external_key: @veteran_participant_id)
      end

      def bgs_jrn_fields
        {
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_obj_id: Settings.bgs.application,
          jrn_status_type_cd: 'U',
          jrn_user_id: Settings.bgs.client_username
        }
      end

      def limitation?(condition)
        @form_data[:consentLimits].present? && @form_data[:consentLimits].include?(condition)
      end

      def add_meta_ids(vet_obj)
        return vet_obj if @vnp_res_object['meta'].blank?

        vet_obj['meta'] ||= {}
        vet_obj['meta'] = remove_nil_values(@vnp_res_object['meta'])

        vet_obj
      end

      def remove_nil_values(res_object_hash)
        res_object_hash.each_with_object({}) do |(key, value), result|
          cleaned_value = value.is_a?(Hash) ? remove_nil_values(value) : value
          result[key] = cleaned_value unless cleaned_value.nil?
        end
      end

      def parse_phone_data(phone_data, location_type)
        return nil if phone_data.blank?

        # is international
        if phone_data[:countryCode].present? && phone_data[:countryCode] != '1'
          return ' ' if location_type == 'domestic'
        elsif location_type == 'international'
          return nil
        end

        "#{phone_data[:areaCode]}#{phone_data[:phoneNumber]}".gsub(/\s/, '')
      end
    end
  end
end
