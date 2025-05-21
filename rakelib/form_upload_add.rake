# frozen_string_literal: true

namespace :form_upload do
  desc 'Add a new form to the Form Upload Tool and integrate with VANotify'
  task :add, [:form_number, :min_pages, :max_pages] => :environment do |t, args|
    require 'fileutils'
    require 'yaml'

    abort 'Usage: rake "form_upload:add[FORM_NUMBER,MIN_PAGES,MAX_PAGES]"' unless args.form_number && args.min_pages && args.max_pages

    form_number = args.form_number.strip
    min_pages = args.min_pages.to_i
    max_pages = args.max_pages.to_i

    # 1. Add to form_upload array in FormProfile::ALL_FORMS
    form_profile_path = 'app/models/form_profile.rb'
    form_upload_marker = 'form_upload: %w['
    form_upload_entry = "      #{form_number}-UPLOAD"
    inserted = false
    lines = File.readlines(form_profile_path)
    File.open(form_profile_path, 'w') do |f|
      lines.each do |line|
        f.puts line
        if line.include?(form_upload_marker) && !inserted
          unless lines.any? { |l| l.include?(form_upload_entry) }
            f.puts form_upload_entry
          end
          inserted = true
        end
      end
    end

    # 1b. Add to FORM_ID_TO_CLASS
    form_id_to_class_marker = 'FORM_ID_TO_CLASS = {'
    form_id_to_class_entry = "    '#{form_number}-UPLOAD' => ::FormProfiles::FormUpload,"
    lines = File.readlines(form_profile_path)
    inserted = false
    inside_hash = false
    output_lines = []
    entries = []
    lines.each do |line|
      if line.include?(form_id_to_class_marker)
        inside_hash = true
        output_lines << line
        next
      end
      if inside_hash
        # End of hash
        if line.strip == '}.freeze'
          inside_hash = false
          # Insert the new entry in order
          # Collect all upload entries, add the new one if not present, sort, then output
          entries << form_id_to_class_entry unless entries.any? { |l| l.include?(form_id_to_class_entry.strip) }
          entries = (entries + []).uniq.sort_by do |entry|
            entry.match(/'([\dA-Za-zP-]+)-UPLOAD'/)[1].gsub(/\D/, '').to_i
          end
          # Ensure each entry is followed by a newline
          output_lines += entries.map { |e| e.end_with?("\n") ? e : "#{e}\n" }
          output_lines << line
          next
        end
        # Collect upload entries
        if line.include?("-UPLOAD' => ::FormProfiles::FormUpload,")
          entries << line.chomp unless entries.any? { |l| l.strip == line.strip }
          next
        end
      end
      output_lines << line
    end
    File.write(form_profile_path, output_lines.join)

    # 2. Add to PersistentAttachments::VAForm::CONFIGS
    va_form_path = 'app/models/persistent_attachments/va_form.rb'
    va_form_marker = ".merge("
    va_form_entry = "      '#{form_number}' => { max_pages: #{max_pages}, min_pages: #{min_pages} },"
    lines = File.readlines(va_form_path)
    inserted = false
    File.open(va_form_path, 'w') do |f|
      lines.each_with_index do |line, idx|
        # Look for the closing bracket of the merge hash
        if !inserted && line.strip == '}'
          unless lines.any? { |l| l.include?(va_form_entry) }
            f.puts va_form_entry
          end
          inserted = true
        end
        f.puts line
      end
    end

    # 3. Add to SUPPORTED_FORMS in FormUploadEmail
    form_upload_email_path = 'modules/simple_forms_api/app/services/simple_forms_api/notification/form_upload_email.rb'
    supported_forms_marker = 'SUPPORTED_FORMS = %w['
    supported_forms_entry = "        #{form_number}"
    inserted = false
    lines = File.readlines(form_upload_email_path)
    File.open(form_upload_email_path, 'w') do |f|
      lines.each do |line|
        f.puts line
        if line.include?(supported_forms_marker) && !inserted
          unless lines.any? { |l| l.include?(supported_forms_entry) }
            f.puts supported_forms_entry
          end
          inserted = true
        end
      end
    end

    puts "\n#{'-' * 72}"
    puts "Form #{form_number} added to Form Upload Tool with min_pages: #{min_pages}, max_pages: #{max_pages}."
    puts 'Please review and commit the changes.'
    puts "#{'-' * 72}\n"
  end
end
