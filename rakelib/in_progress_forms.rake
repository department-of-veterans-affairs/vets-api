# frozen_string_literal: true

namespace :form_progress do
  desc 'Get the last page a user completed before leaving the form'
  # bundle exec rake form_progress:return_url[21-526EZ,2020-10-06,2020-11-06]
  task :return_url, %i[form_id start_date end_date] => [:environment] do |_, args|
    forms = forms_with_args(args)
    data = forms.select(InProgressForm::RETURN_URL_SQL)
                .group(InProgressForm::RETURN_URL_SQL).order(Arel.sql('count(*)')).count
    puts data
  end

  desc 'Get counts of last page a user completed before validation errors'
  # bundle exec rake form_progress:error_url[21-526EZ,2020-10-06,2020-11-06]
  task :error_url, %i[form_id start_date end_date] => [:environment] do |_, args|
    forms = forms_with_args(args)
    data = forms.has_errors.select(InProgressForm::RETURN_URL_SQL)
                .group(InProgressForm::RETURN_URL_SQL).order(Arel.sql('count(*)')).count
    puts data
  end

  desc 'Get counts of last page a user completed before abandoning (without errors)'
  # bundle exec rake form_progress:abandon_url[21-526EZ,2020-10-06,2020-11-06]
  task :abandon_url, %i[form_id start_date end_date] => [:environment] do |_, args|
    forms = forms_with_args(args)
    data = forms.has_no_errors.select(InProgressForm::RETURN_URL_SQL)
                .group(InProgressForm::RETURN_URL_SQL).order(Arel.sql('count(*)')).count
    puts data
  end

  desc 'Get validation errors for a given form return_url'
  # bundle exec rake form_progress:errors_for_return_url[21-526EZ,2020-10-06,2020-11-06,/review-and-submit]
  task :errors_for_return_url, %i[form_id start_date end_date return_url] => [:environment] do |_, args|
    forms = forms_with_args(args)
    data = forms.has_errors.return_url(args[:return_url]).pluck(:metadata)
    puts data
  end

  desc 'Get the metadata for users who got an error_message on submission'
  # bundle exec rake form_progress:error_messages[21-526EZ,2020-10-06,2020-11-06]
  task :error_messages, %i[form_id start_date end_date] => [:environment] do |_, args|
    forms = forms_with_args(args)
    data = forms.has_error_message.pluck(:metadata)
    puts data
  end

  desc 'Get metadata for in-progress FSR forms that haven\'t been submitted'
  task :pending_fsr, %i[start_date end_date] => [:environment] do |_, args|
    start_date = args[:start_date]&.to_date || 31.days.ago.utc
    end_date = args[:end_date]&.to_date || 1.day.ago
    forms = InProgressForm.unsubmitted_fsr.where(updated_at: [start_date.beginning_of_day..end_date.end_of_day])
    puts '------------------------------------------------------------'
    puts "* #{forms.length} unsubmitted FSR form#{forms.length == 1 ? '' : 's'} from  #{start_date} to #{end_date} *"
    puts '------------------------------------------------------------'
    puts forms.pluck :metadata
  end

  def forms_with_args(args)
    form_id = args[:form_id] || '21-526EZ'
    start_date = args[:start_date]&.to_date || 31.days.ago.utc
    end_date = args[:end_date]&.to_date || 1.day.ago
    puts '------------------------------------------------------------'
    puts "* #{form_id} from #{start_date} to #{end_date} *"
    puts '------------------------------------------------------------'
    InProgressForm.where(updated_at: [start_date.beginning_of_day..end_date.end_of_day], form_id:)
  end
end
