namespace :user_actions do
  task :cleanup do
    cutoff_date = 1.year.ago

    UserAction.where('created_at < ?', cutoff_date).destroy_all

    puts "Deleted UserActions older than #{cutoff_date}"
  end
end