# frozen_string_literal: true

module VAOS
  module V2
    class ProvidersSerializer
      include FastJsonapi::ObjectSerializer

      set_id :provider_identifier

      set_type :providers

      attributes :provider_identifier,
                 :provider_identifier_type,
                 :name,
                 :provider_type,
                 :address,
                 :address_street,
                 :address_city,
                 :address_state_province,
                 :address_county,
                 :provider_status_reason,
                 :primary_care_physician,
                 :is_accepting_new_patients,
                 :provider_gender,
                 :is_external,
                 :can_create_health_care_orders,
                 :contact_method_email,
                 :contact_method_fax,
                 :contact_method_virtu_pro,
                 :contact_method_hsrm,
                 :contact_method_phone,
                 :contact_method_mail,
                 :contact_method_ref_doc,
                 :bulk_emails,
                 :bulk_mails,
                 :emails,
                 :mails,
                 :phone_calls,
                 :faxes,
                 :preferred_means_receiving_referral_hsrm,
                 :preferred_means_receiving_referral_secured_email,
                 :preferred_means_receiving_referral_mail,
                 :preferred_means_receiving_referral_direct_messaging,
                 :preferred_means_receiving_referral_fax,
                 :modified_on_date
    end
  end
end
