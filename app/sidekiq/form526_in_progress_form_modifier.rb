# frozen_string_literal: true

class Form526InProgressFormModifier
  include Sidekiq::Job
  sidekiq_options retry: false

  STATSD_PREFIX = 'form526.in_progress_form_modifier'
  # TODO: Update this URL to the new return URL once it is finalized
  NEW_RETURN_URL = '/tbd/url'

  def perform(ipf_id_array)
    raise ArgumentError, 'ipf_id_array must be an array' unless ipf_id_array.is_a?(Array)
    raise ArgumentError, 'ipf_id_array cannot be empty' if ipf_id_array.empty?

    in_progress_forms = InProgressForm.where(id: ipf_id_array, form_id: FormProfiles::VA526ez::FORM_ID).where("metadata->>'return_url' != '#{NEW_RETURN_URL}'")
    raise ArgumentError, "No in-progress forms with the form id (#{FormProfiles::VA526ez::FORM_ID}) found for the provided IDs" if in_progress_forms.empty?


    Rails.logger.info("Running InProgress forms modifier for #{in_progress_forms.count} forms")
    in_progress_forms.each do |in_progress_form|
      in_progress_form.id
      form_parsed = JSON.parse(in_progress_form.form_data)
      form_parsed.dig('view:patient_acknowledgement', 'view:acknowledgement')
    end
  rescue => e
    Rails.logger.error('Error logging Running InProgress forms modifier',
                       class: self.class.name,
                       message: e.try(:message))
  end
end
