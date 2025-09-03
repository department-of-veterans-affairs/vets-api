# frozen_string_literal: true

module RepresentationManagement
  module AccreditedEntities
    class IndividualSerializer
      include JSONAPI::Serializer

      attributes :first_name, :last_name, :full_name,
                 :address_line1,
                 :address_line2, :address_line3, :address_type,
                 :city, :country_name, :country_code_iso3, :province,
                 :international_postal_code, :state_code, :zip_code, :zip_suffix,
                 :phone, :email

      attribute :individual_type do |object|
        if object.respond_to?(:individual_type)
          object.individual_type
        else
          Array(object.try(:user_types)).first
        end
      end

      attribute :accredited_organizations do |object|
        orgs = if object.respond_to?(:accredited_organizations)
                 object.accredited_organizations
               else
                 object.organizations
               end
        RepresentationManagement::OriginalEntities::OrganizationSerializer.new(orgs)
      end
    end
  end
end
