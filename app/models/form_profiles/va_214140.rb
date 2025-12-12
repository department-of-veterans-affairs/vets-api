# frozen_string_literal: true

# FormProfile for VA Form 21-4140
# Employment Questionnaire
class FormProfiles::VA214140 < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/name-and-date-of-birth'
    }
  end
end
