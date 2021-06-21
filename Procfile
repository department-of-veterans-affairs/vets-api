web: bundle exec puma -p 3000 -C ./config/puma.rb
critical_job: bundle exec sidekiq -q critical,2 -q high,1
default_job: bundle exec sidekiq -q default,2 -q low,1
freshclam: /usr/bin/freshclam -d --config-file=config/freshclam.conf
clamd: /usr/sbin/clamd -c config/clamd.conf
