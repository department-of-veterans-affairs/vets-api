# frozen_string_literal: true

class Form526InProgressFormModifier
  include Sidekiq::Job
  sidekiq_options retry: false

  NEW_RETURN_URL = '/supporting-evidence/private-medical-records-authorize-release'

  def validate_ipf_id_array_return_ipfs(ipf_id_array)
    raise ArgumentError, 'ipf_id_array must be an array' unless ipf_id_array.is_a?(Array)
    raise ArgumentError, 'ipf_id_array cannot be empty' if ipf_id_array.empty?

    in_progress_forms = InProgressForm.where(id: ipf_id_array,
                                             form_id: FormProfiles::VA526ez::FORM_ID)
                                      .where("metadata->>'return_url' != '#{NEW_RETURN_URL}'")
    if in_progress_forms.empty?
      raise ArgumentError,
            "No in-progress forms with the form id (#{FormProfiles::VA526ez::FORM_ID}) found for the provided IDs"
    else
      in_progress_forms
    end
  end

  def change_return_url(in_progress_form, current_in_progress_form_id)
    Rails.logger.info('Updating return URL for in-progress',
                      current_in_progress_form_id:,
                      new_return_url: NEW_RETURN_URL,
                      old_return_url: in_progress_form.metadata['return_url'],
                      dry_run: true)
    # Dry runs.. dont update yet
    # in_progress_form.metadata['return_url'] = NEW_RETURN_URL
    # in_progress_form.save!
  end

  def perform(ipf_id_array)
    in_progress_forms = validate_ipf_id_array_return_ipfs(ipf_id_array)

    Rails.logger.info("Running InProgress forms modifier for #{in_progress_forms.count} forms")
    current_in_progress_form_id = nil
    in_progress_forms.each do |in_progress_form|
      current_in_progress_form_id = in_progress_form.id
      form_parsed = JSON.parse(in_progress_form.form_data)

      # TODO: Check this is the correct acknowldegement
      if form_parsed.dig('view:patient_acknowledgement', 'view:acknowledgement') == true
        change_return_url(in_progress_form, current_in_progress_form_id)
      else
        Rails.logger.info('No update needed for in-progress form', current_in_progress_form_id:, dry_run: true)
      end
    end
  rescue => e
    Rails.logger.error('Error in InProgress forms modifier',
                       in_progress_form_ids: ipf_id_array,
                       class: self.class.name,
                       message: e.try(:message),
                       current_in_progress_form_id:)
  end
end
