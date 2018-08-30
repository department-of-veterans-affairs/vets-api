# frozen_string_literal: true

class FormProfiles::FeedbackTool < FormProfile
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant-relationship'
    }
  end

  def convert_country!(form_data)
    country = form_data.try(:[], 'address').try(:[], 'country')

    form_data['address']['country'] = IsoCountryCodes.find(country).alpha2 if country.present? && country.size == 3
  end

  def prefill(*args)
    return_val = super
    convert_country!(return_val[:form_data])

    return_val
  end
end
