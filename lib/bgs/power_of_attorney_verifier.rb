# frozen_string_literal: true

module BGS
  class PowerOfAttorneyVerifier
    def initialize(user)
      @user = user
      @veteran = Veteran::User.new(@user)
    end

    def current_poa
      @current_poa ||= @veteran.power_of_attorney
    end

    # Returns the current Power of Attorney code for the veteran.
    #
    # POA assignments can have time limits. The end_date attribute on the PowerOfAttorney
    # model is auto-populated when retrieving POA information from BGS. When respect_expiration
    # is true, this method checks the end_date and returns nil if the POA has expired.
    #
    # @param respect_expiration [Boolean] if true, returns nil for expired POAs (end_date in the past)
    # @return [String, nil] the POA code, or nil if no POA exists or POA is expired
    #
    # @example Get current POA code without expiration check
    #   verifier.current_poa_code
    #   #=> "A1Q"
    #
    # @example Get POA code only if not expired
    #   verifier.current_poa_code(respect_expiration: true)
    #   #=> nil (if expired)
    #
    # @see https://github.com/department-of-veterans-affairs/vets-api/pull/22780
    #
    # TODO: Refactor other calls so expiration is always checked & argument can be removed
    def current_poa_code(respect_expiration: false)
      if respect_expiration && current_poa.try(:end_date).present?
        expiration_date = Date.strptime(current_poa.end_date, '%m/%d/%Y')
        return nil if expiration_date < Time.zone.today
      end

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
