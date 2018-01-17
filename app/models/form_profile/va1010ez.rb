# frozen_string_literal: true

class FormProfile::VA1010ez < FormProfile
  def prefill(user)
    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information/personal-information'
    }
  end

  private

  def derive_postal_code(user)
    postal_code = {}

    if user.va_profile&.address
      country = user.va_profile.address.country
      postal_code_key = %w[USA MEX CAN].include?(country) ? :zipcode : :postal_code
      postal_code[postal_code_key] = user.va_profile.address.postal_code
    end

    postal_code
  end
end
