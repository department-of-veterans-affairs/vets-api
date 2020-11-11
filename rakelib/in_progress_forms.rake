# frozen_string_literal: true

namespace :form_progress do
  desc 'The last page a user completed before leaving the form'
  # bundle exec rake form_progress:return_url[21-526EZ,2020-10-06,2020-11-06]
  task :return_url, %i[form_id start_date end_date] => [:environment] do |_, args|
    forms = forms_with_args(args)
    data = forms.select(InProgressForm::RETURN_URL_SQL).group(InProgressForm::RETURN_URL_SQL).count
    puts data
  end

  desc 'The last page a user completed before error'
  # bundle exec rake form_progress:error_url[21-526EZ,2020-10-06,2020-11-06]
  task :error_url, %i[form_id start_date end_date] => [:environment] do |_, args|
    forms = forms_with_args(args)
    data = forms.has_errors.select(InProgressForm::RETURN_URL_SQL).group(InProgressForm::RETURN_URL_SQL).count
    puts data
  end

  desc 'The last page a user completed before error_message'
  # bundle exec rake form_progress:error_message_url[21-526EZ,2020-10-06,2020-11-06]
  task :error_message_url, %i[form_id start_date end_date] => [:environment] do |_, args|
    forms = forms_with_args(args)
    data = forms.has_error_message.select(InProgressForm::RETURN_URL_SQL).group(InProgressForm::RETURN_URL_SQL).count
    puts data
  end

  desc 'The last page a user completed before error_message'
  # bundle exec rake form_progress:error_messages_for_url[21-526EZ,2020-10-06,2020-11-06,/review-and-submit]
  task :error_messages_for_url, %i[form_id start_date end_date return_url] => [:environment] do |_, args|
    forms = forms_with_args(args)
    data = forms.return_url(args[:return_url]).has_error_message.pluck(:metadata)
    puts data
  end

  def forms_with_args(args)
    form_id = args[:form_id] || '21-526EZ'
    start_date = args[:start_date]&.to_date || 30.days.ago.utc
    end_date = args[:end_date]&.to_date || Time.zone.now.utc
    puts '------------------------------------------------------------'
    puts "* #{form_id} from #{start_date} to #{end_date} *"
    puts '------------------------------------------------------------'
    InProgressForm.where(updated_at: [start_date.beginning_of_day..end_date.end_of_day], form_id: form_id)
  end
end
