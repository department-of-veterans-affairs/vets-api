# frozen_string_literal: true

# FormProfile for VA Form 21-2680
# Examination for Housebound Status or Permanent Need for Regular Aid and Attendance
class FormProfiles::VA212680 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end
end
