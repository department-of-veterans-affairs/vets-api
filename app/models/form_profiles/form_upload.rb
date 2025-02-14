# frozen_string_literal: true

class FormProfiles::FormUpload < FormProfile
  def self.load_form_mapping(_form_id)
    file = Rails.root.join('config', 'form_profile_mappings', 'FORM-UPLOAD.yml')

    YAML.load_file(file)
  end

  def prefill(*args)
    super

    # binding.pry
  end

  # def generate_prefill(_mappings)
  #   prefill = super

  #   binding.pry
  #   last_uploaded_form = PersistentAttachments::VAForm.find(form_id:).last
  #   prefill
  # end

  def metadata
    {
      version: 0,
      prefill: true
    }
  end
end
