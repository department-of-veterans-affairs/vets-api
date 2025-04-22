# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ClaimantSerializer < ApplicationSerializer
    set_id do |profile|
      IcnTemporaryIdentifier.save_icn(profile.icn).id
    end

    attribute :first_name do |profile|
      profile.given_names.first
    end

    attribute :last_name, &:family_name

    attribute :city do |profile|
      profile.address.city
    end

    attribute :state do |profile|
      profile.address.state
    end

    attribute :postal_code do |profile|
      profile.address.postal_code
    end

    attribute :representative do |_, params|
      params[:representative]
    end

    attribute :poa_requests do |profile, params|
      params[:poa_requests].joins(:claimant).where(claimant: { icn: profile.icn }).map do |poa_request|
        PowerOfAttorneyRequestSerializer.new(poa_request).serializable_hash
      end
    end
  end
end
