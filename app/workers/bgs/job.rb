# frozen_string_literal: true

module BGS
  class Job
    def in_progress_form_copy(in_progress_form)
      return nil if in_progress_form.blank?

      OpenStruct.new(meta_data: in_progress_form.metadata,
                     form_data: in_progress_form.form_data,
                     user_account: in_progress_form.user_account)
    end

    def salvage_save_in_progress_form(form_id, user_uuid, copy)
      return if copy.blank?

      form = InProgressForm.where(form_id:, user_uuid:).first_or_initialize
      form.user_account = copy.user_account
      form.update(form_data: copy.form_data)
    end

    # BGS doesn't accept name and address_line fields with non-ASCII characters (e.g. ü, ñ), and doesn't accept names
    # with apostrophes. This method recursively iterates through a given hash and strips unprocessable characters
    # from name and address_line fields. The method is called in `SubmitForm686cJob` and `SubmitForm674Job` with an
    # enormous form payload potentially containing many names and addresses.
    # See `spec/factories/686c/form_686c_674.rb` for an example of such a payload.
    def normalize_names_and_addresses!(hash)
      hash.each do |key, val|
        case val
        when Hash
          normalize_names_and_addresses!(val)
        when Array
          val.each { |v| normalize_names_and_addresses!(v) if v.is_a?(Hash) }
        else
          is_name_key = %w[first middle last].include?(key)
          if val && (is_name_key || key.include?('address_line'))
            # NFKD decomposes composite characters (e.g. ü, ñ) into their individual components, and here, `gsub`
            # removes any non-ASCII components (e.g. ü -> u; ñ -> n).
            val = val.unicode_normalize(:nfkd).gsub(/[^\p{ASCII}]/, '')
            # Interestingly, BGS permits names with forward slashes and hyphens, but not apostrophes.
            val.gsub!(%r{[^a-zA-Z\s/-]}, '') if is_name_key
            hash[key] = val
          end
        end
      end
    end
  end
end
