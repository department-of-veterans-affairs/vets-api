# frozen_string_literal: true

class FormProfiles::VA281900 < FormProfile
    attribute :is_logged_in, Boolean

    def prefill(user)
        @is_logged_in = true
        super(user)
    end

    def metadata
        {
            version: 0,
            prefill: true,
            returnUrl: '/veteran-information-review'
        }
    end
end