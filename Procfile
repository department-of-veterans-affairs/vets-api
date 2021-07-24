web: bundle exec puma -p 3000 -C ./config/puma.rb
job: bundle exec sidekiq -q critical,4 -q tasker,3 -q default,2 -q low,1
freshclam: /usr/bin/freshclam -d --config-file=config/freshclam.conf
clamd: /usr/sbin/clamd -c config/clamd.conf
