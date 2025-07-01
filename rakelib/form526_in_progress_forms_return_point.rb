namespace :form526 do
  desc 'Set new return url data for in-progress Form 526 submissions'
  task in_progress_forms_return_point: :environment do
    new_return_url = '/new-disabilities/add'

    potentially_affected_forms = InProgressForm.where(form_id: '21-526EZ')
                  .where(created_at: Date.parse('2025-06-26')..Date.parse('2025-06-30'))
                  .where("metadata->'submission'->>'has_attempted_submit' = 'true'")
    puts "Found #{potentially_affected_forms.count} potentially affected forms."
    potentially_affected_forms.each do |form|
      id = form.id
      form_parsed = JSON.parse(form.form_data)
      nd = form_parsed.dig("new_disabilities")
      next if nd.nil?
      is_affected = nd.any? {|d| d.key?('condition') && d.keys.size == 1}
      if is_affected
        form.metadata = form.metadata.merge('return_url' => new_return_url)
        form.save!
        puts "Updated form with ID: #{id}"
        affected << id
    end
    puts affected
  end

