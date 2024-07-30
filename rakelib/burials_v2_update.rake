# frozen_string_literal: true

namespace :burials_v2 do
  desc 'Perform migration of 21p-530 in progress forms to v2'
  task update: :environment do
    InProgressForm.where(form_id: '21P-530').find_in_batches do |group|
      sleep(0.05) # short pause between batches

      group.each do |ipf|
        ipf.metadata['return_url'] = '/claimant-information'
        parsed_form = JSON.parse ipf.form_data

        parsed_form['relationship']['type'] = nil if parsed_form.dig('relationship', 'type') == 'other'

        if parsed_form.dig('location_of_death', 'location') == 'other'
          parsed_form['location_of_death']['location'] = nil
        end

        ipf.form_data = parsed_form.to_json

        ipf.form_id = '21P-530V2'

        ipf.save
      end
    end
  end
end
