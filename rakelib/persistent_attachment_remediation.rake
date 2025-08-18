# frozen_string_literal: true

def sanitize_attachments_for_key(claim, key, attachments, ipf_form_data, destroyed_names, delete_claim, dry_run) # rubocop:disable Metrics/ParameterLists
  attachments.each do |attachment|
    attachment.file_data || attachment.saved_claim_id.nil?
  rescue => e
    puts "Attachment #{attachment.id} failed to decrypt: #{e.class}"
    if dry_run
      puts "[DRY RUN] Would destroy attachment #{attachment.id}"
    else
      attachment.delete
    end

    ipf_form_data = update_ipf_form_data(attachment, claim, ipf_form_data, key, destroyed_names)

    delete_claim = true
  end
  [delete_claim, ipf_form_data || nil]
end

def update_ipf_form_data(attachment, claim, ipf_form_data, key, destroyed_names)
  # Retrieve the proper key for the form data section.
  form_key = claim.respond_to?(:attachment_key_map) ? (claim.attachment_key_map[key] || key) : key

  # Get the section of the form data either from ipf_form_data or by parsing claim.form.
  form_data_section = if ipf_form_data
                        ipf_form_data.send(form_key)
                      elsif claim.form.present?
                        JSON.parse(claim.form, object_class: OpenStruct).send(key)
                      end

  # Find the destroyed attachment in the form data section.
  destroyed_attachment = form_data_section&.find do |att|
    (att.respond_to?(:confirmation_code) && att.confirmation_code == attachment.guid) ||
      (att.respond_to?(:confirmationCode) && att.confirmationCode == attachment.guid)
  end

  puts "Add destroyed attachment file to list: #{destroyed_attachment&.name}"
  destroyed_names << destroyed_attachment&.name

  # Remove the destroyed attachment from the section.
  form_data_section&.reject! do |att|
    (att.respond_to?(:confirmation_code) && att.confirmation_code == attachment.guid) ||
      (att.respond_to?(:confirmationCode) && att.confirmationCode == attachment.guid)
  end

  # Update ipf_form_data if available.
  ipf_form_data&.send("#{form_key}=", form_data_section)

  ipf_form_data
end

def scrub_email(email)
  prefix, domain = email.split('@')
  masked_local = prefix[0] + ('*' * (prefix.length - 1))
  "#{masked_local}@#{domain}"
end

def mask_file_name(filename)
  return filename if filename.nil? || filename.strip.empty?

  ext = File.extname(filename)
  base = File.basename(filename, ext)

  # If the base is too short, just return the filename unchanged.
  return filename if base.length <= 4

  first_two = base[0, 2]
  last_two  = base[-2, 2]
  stars = '*' * (base.length - 4)

  "#{first_two}#{stars}#{last_two}#{ext}"
end

#
# bundle exec rake persistent_attachment_remediation:run['264 265 267',true] Burials
# bundle exec rake persistent_attachment_remediation:run['273 274 275',true] Pensions
namespace :persistent_attachment_remediation do
  desc 'Remediate SavedClaims and attachments by claim id. Deletes claims with bad attachments and notifies by email.'
  task :run, %i[claim_ids dry_run] => :environment do |_, args|
    claim_ids = args[:claim_ids]&.split&.map(&:strip)
    dry_run = args[:dry_run].to_s == 'true'
    unless claim_ids&.any?
      puts 'Usage: rake persistent_attachment_remediation:run[CLAIM_ID1,CLAIM_ID2,...]'
      exit 1
    end

    updated_time = Time.zone.local(2025, 6, 18, 0, 0, 0)
    unique_emails_for_notification = Set.new
    vanotify_service = ''
    personalization = {}

    claim_ids.each do |claim_id|
      puts '========================================'
      claim = SavedClaim.find_by(id: claim_id)
      unless claim
        puts "SavedClaim with id #{claim_id} not found."
        next
      end

      # If the claim is a type-casted STI base class, try the module-specific classes
      if claim && ['SavedClaim::Burial', 'SavedClaim::Pension'].include?(claim.type)
        type_map = {
          'SavedClaim::Burial' => Burials::SavedClaim,
          'SavedClaim::Pension' => Pensions::SavedClaim
        }
        claim = claim.becomes(type_map[claim.type])
      end

      puts "Step 1: Start processing a #{claim.class.name} with id: #{claim_id}"
      vanotify_service = claim&.form_id&.downcase&.gsub(/-/, '_')

      # Find InProgressForm with matching email and SSN from Claim
      puts 'Step 2: Searching InProgressForms against claim\'s email and SSN...'
      claim_email = claim.email || claim.open_struct_form&.claimantEmail # Pensions || Burial
      claim_veteran_ssn = claim.open_struct_form&.veteranSocialSecurityNumber
      ipf = InProgressForm.where(form_id: claim.form_id)
                          .where('updated_at >= ?', updated_time)
                          .find do |ipf|
        JSON.parse(ipf.form_data).then do |data|
          email = data['email'] || data['claimant_email']
          email == claim_email && data['veteran_social_security_number'] == claim_veteran_ssn
        end
      rescue
        false
      end

      if ipf
        puts "Found InProgressForm: #{ipf.id}"
        ipf_form_data = JSON.parse(ipf&.form_data, object_class: OpenStruct)
      end

      # Gather expected attachment GUIDs from the claim's form data
      updated_ipf_form_data = ipf_form_data
      if claim.respond_to?(:attachment_keys) && claim.respond_to?(:open_struct_form)
        delete_claim_array = []
        destroyed_names = []
        puts "Step 3: Sanitizing attachments for claim id: #{claim.id}"
        claim.attachment_keys.each do |key|
          guids = Array(claim.open_struct_form.send(key)).map do |att|
            att.try(:confirmationCode) || att.try(:confirmation_code)
          end
          attachments = PersistentAttachment.where(guid: guids)

          delete_claim, updated_ipf_form_data =
            sanitize_attachments_for_key(claim, key, attachments, updated_ipf_form_data, destroyed_names, delete_claim,
                                         dry_run)

          delete_claim_array << delete_claim
        end
      end

      if dry_run
        puts "[DRY RUN] Would update InProgressForm #{ipf&.id}"
      elsif updated_ipf_form_data
        puts "Step 4: Updating InProgressForm #{ipf&.id} with sanitized form data"
        ipf.update!(form_data: Common::HashHelpers.deep_to_h(updated_ipf_form_data).to_json)
      end

      if delete_claim_array.any?
        if claim.email.present?
          unique_emails_for_notification << claim.email
          data = JSON.parse(claim.form)
          if claim.form_id == '21P-527EZ'
            claim_type = 'Application for Veterans Pension (VA Form 21P-527EZ)'
            url = 'http://va.gov/pension/apply-for-veteran-pension-form-21p-527ez'
          else
            claim_type = 'Application for Veterans Burial (VA Form 21P-530EZ)'
            url = 'http://va.gov/burials-and-memorials/apply-burial-benefits-form-21p-530ez'
          end
          first_name = data.dig('claimantFullName', 'first') || data.dig('veteranFullName', 'first')
          personalization = {
            first_name:,
            claim_type:,
            url:,
            file_count: destroyed_names.size,
            file_names: destroyed_names.map { |name| mask_file_name(name) }.join(",\n ")
          }
        end
        puts "Step 5: Destroying claim #{claim.id} due to invalid attachments"
        if dry_run
          puts "[DRY RUN] Would destroy SavedClaim #{claim.id}"
        else
          claim.destroy!
        end
      else
        puts "All attachments for SavedClaim #{claim.id} are valid and decryptable"
      end
    end

    # Send out emails to unique email list
    if unique_emails_for_notification.size.positive?
      scrubbed_emails = unique_emails_for_notification.to_a.map { |email| scrub_email(email) }.join(', ')
      puts "Step 6: Sending remediation email to unique email(s): #{scrubbed_emails}"
      unique_emails_for_notification.each do |email|
        if dry_run
          puts "[DRY RUN] Would send remediation email to #{scrub_email(email)}"
        else
          service_config = Settings.vanotify.services[vanotify_service]
          VANotify::EmailJob.perform_async(
            email,
            service_config.email.persistent_attachment_error.template_id,
            personalization,
            service_config.api_key
          )
        end
      end
    end
  end
end
