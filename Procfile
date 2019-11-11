web: bundle exec bin/rails s -b 0.0.0.0 -p 3000
job: bundle exec sidekiq -q default -q critical -q tasker
clamav: /usr/sbin/clamd -c config/clamd.conf