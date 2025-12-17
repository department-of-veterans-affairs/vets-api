# frozen_string_literal: true

# FormProfile for VA Form 21-2680
# Examination for Housebound Status or Permanent Need for Regular Aid and Attendance
#
# This form can be filed by Veterans (for themselves) or by family members
# (spouse, child, parent) on behalf of a Veteran. The prefill logic only
# populates veteran information fields when the logged-in user is a verified
# Veteran, preventing non-veteran family members from having their personal
# info incorrectly placed in the Veteran fields.
class FormProfiles::VA212680 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end

  # Override prefill to only populate veteran information when the user is a verified Veteran.
  # Non-veteran users (family members filing on behalf of a Veteran) will receive
  # an empty form_data, requiring them to manually enter the Veteran's information.
  def prefill
    return { form_data: {}, metadata: } unless user_is_veteran?

    super
  end

  private

  def user_is_veteran?
    user.veteran?
  rescue => e
    Rails.logger.error("VA212680 veteran status check failed: #{e.message}")
    false
  end
end
