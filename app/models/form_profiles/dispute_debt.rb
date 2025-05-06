# frozen_string_literal: true

class FormProfiles::DisputeDebt < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/personal-information'
    }
  end

  private

  def va_file_number_last_four
    return unless user.authorize :debt, :access?

    file_number =
      begin
        response = BGS::People::Request.new.find_person_by_participant_id(user:)
        response.file_number.presence || user.ssn
      rescue
        user.ssn
      end

    file_number&.last(4)
  end
end
