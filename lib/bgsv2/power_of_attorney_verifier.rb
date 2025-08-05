# frozen_string_literal: true

module BGSV2
  class PowerOfAttorneyVerifier
    def initialize(user)
      @user = user
      @veteran = Veteran::User.new(@user)
    end

    def current_poa
      @current_poa ||= @veteran.power_of_attorney
    end

    def current_poa_code
      current_poa.try(:code)
    end

    def previous_poa_code
      @previous_poa_code ||= @veteran.previous_power_of_attorney.try(:code)
    end

    def verify(user)
      reps = Veteran::Service::Representative.all_for_user(first_name: user.first_name,
                                                           last_name: user.last_name)
      raise ::Common::Exceptions::Unauthorized, detail: 'VSO Representative Not Found' if reps.blank?

      if reps.count > 1
        if user.middle_name.blank?
          raise ::Common::Exceptions::Unauthorized, detail: 'Ambiguous VSO Representative Results'
        else
          reps = representatives_with_middle_names_for_user(user)
          raise ::Common::Exceptions::Unauthorized, detail: 'VSO Representative Not Found' if reps.blank?
          raise ::Common::Exceptions::Unauthorized, detail: 'Ambiguous VSO Representative Results' if reps.count > 1
        end
      end

      rep = reps.first
      veteran_poa_code = current_poa_code
      unless matches(veteran_poa_code, rep)
        Rails.logger.info("POA code of #{rep.poa_codes.join(', ')} not valid for veteran code #{veteran_poa_code}")
        raise ::Common::Exceptions::Unauthorized, detail: "Power of Attorney code doesn't match Veteran's"
      end
    end

    def matches(veteran_poa_code, representative)
      representative.poa_codes.include?(veteran_poa_code)
    end

    private

    def representatives_with_middle_names_for_user(user)
      middle_initial = user.middle_name[0]
      reps = Veteran::Service::Representative.all_for_user(first_name: user.first_name,
                                                           last_name: user.last_name,
                                                           middle_initial:)

      if reps.blank? || reps.count > 1
        reps = Veteran::Service::Representative.all_for_user(first_name: user.first_name,
                                                             last_name: user.last_name,
                                                             poa_code: current_poa_code)
      end
      reps
    end
  end
end
