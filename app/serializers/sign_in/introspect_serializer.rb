# frozen_string_literal: true

module SignIn
  class IntrospectSerializer < ActiveModel::Serializer
    attributes :uuid, :first_name, :middle_name, :last_name, :birth_date,
               :email, :gender, :ssn, :birls_id, :authn_context,
               :icn, :edipi, :active_mhv_ids, :sec_id, :vet360_id,
               :participant_id, :cerner_id, :cerner_facility_ids,
               :vha_facility_ids, :id_theft_flag, :verified, :access_token_ttl

    delegate :uuid, to: :object
    delegate :first_name, to: :object
    delegate :middle_name, to: :object
    delegate :last_name, to: :object
    delegate :birth_date, to: :object
    delegate :email, to: :object
    delegate :gender, to: :object
    delegate :ssn, to: :object
    delegate :birls_id, to: :object
    delegate :icn, to: :object
    delegate :edipi, to: :object
    delegate :active_mhv_ids, to: :object
    delegate :sec_id, to: :object
    delegate :vet360_id, to: :object
    delegate :participant_id, to: :object
    delegate :cerner_id, to: :object
    delegate :cerner_facility_ids, to: :object
    delegate :vha_facility_ids, to: :object
    delegate :id_theft_flag, to: :object
    delegate :authn_context, to: :object

    def id; end

    def access_token_ttl
      SignIn::Constants::AccessToken::VALIDITY_LENGTH_MINUTES.minutes.seconds.to_i
    end

    def verified
      object.loa3?
    end
  end
end
