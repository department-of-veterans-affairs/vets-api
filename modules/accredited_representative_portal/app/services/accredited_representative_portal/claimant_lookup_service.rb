# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ClaimantLookupService
    def initialize(first_name, last_name, ssn, birth_date)
      @first_name = first_name
      @last_name = last_name
      @ssn = ssn.try(:gsub, /\D/, '')
      @birth_date = birth_date
    end

    def claimant_profile
      @claimant_profile ||= MPI::Service.new.find_profile_by_attributes(
        first_name: @first_name, last_name: @last_name,
        ssn: @ssn, birth_date: @birth_date
      ).profile
    end

    def icn
      validate_params

      claimant_profile.present? or
        raise Common::Exceptions::RecordNotFound, 'Claimant not found'

      claimant_profile.icn
    end

    def validate_params
      unless [@first_name, @last_name, @ssn, @birth_date].all?(&:present?)
        missing_params = []
        %w[first_name last_name ssn birth_date].each do |param|
          missing_params << param if instance_values[param].blank?
        end
        raise ActionController::BadRequest, "Missing parameters: #{missing_params.join(',')}"
      end
    end

    def self.get_icn(first_name, last_name, ssn, birth_date)
      new(first_name, last_name, ssn, birth_date).icn
    end
  end
end
