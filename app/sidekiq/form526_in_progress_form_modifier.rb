# frozen_string_literal: true

class Form526InProgressFormModifier
  include Sidekiq::Job
  sidekiq_options retry: false

  NEW_RETURN_URL = '/supporting-evidence/private-medical-records-authorize-release'

  def perform(ipf_id_array)
    raise ArgumentError, 'ipf_id_array must be an array' unless ipf_id_array.is_a?(Array)
    raise ArgumentError, 'ipf_id_array cannot be empty' if ipf_id_array.empty?

    in_progress_forms = InProgressForm.where(id: ipf_id_array,
                                             form_id: FormProfiles::VA526ez::FORM_ID).where("metadata->>'return_url' != '#{NEW_RETURN_URL}'")
    if in_progress_forms.empty?
      raise ArgumentError,
            "No in-progress forms with the form id (#{FormProfiles::VA526ez::FORM_ID}) found for the provided IDs"
    end

    Rails.logger.info("Running InProgress forms modifier for #{in_progress_forms.count} forms")
    in_progress_forms.each do |in_progress_form|
      form_parsed = JSON.parse(in_progress_form.form_data)
      if form_parsed.dig('view:patient_acknowledgement', 'view:acknowledgement') == true
        Rails.logger.info('Dry-run: Updating return URL for in-progress', in_progress_form_id: in_progress_form.id,
                                                                          new_return_url: NEW_RETURN_URL, old_return_url: in_progress_form.metadata['return_url'])
        # Dry runs.. dont update yet
        # in_progress_form.metadata['return_url'] = NEW_RETURN_URL
        # in_progress_form.save!
      else
        Rails.logger.info('Dry-run: No update needed for in-progress form', in_progress_form_id: in_progress_form.id)
      end
    end
  rescue => e
    Rails.logger.error('Error in InProgress forms modifier',
                       in_progress_form_ids: ipf_id_array,
                       class: self.class.name,
                       message: e.try(:message))
  end
end
