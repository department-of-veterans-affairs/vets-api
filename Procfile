web: bundle exec bin/rails s -b 0.0.0.0 -p 3000
job: bundle exec sidekiq -q default -q critical -q tasker
freshclam: /usr/bin/freshclam -d --config-file=config/freshclam.conf
clamd: /usr/sbin/clamd -c config/clamd.conf
