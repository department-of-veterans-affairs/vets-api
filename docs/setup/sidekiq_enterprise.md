### Sidekiq Configuration
We use [Sidekiq Enterprise (`sidekiq-ent` & `sidekiq-pro`)](https://sidekiq.org/products/enterprise.html) which requires a product license to download. Only members of the internal team have access to this license. Alternatively, you may use plain old [`sidekiq`](https://github.com/mperham/sidekiq) by setting the environment variable:

```
EXCLUDE_SIDEKIQ_ENTERPRISE=true
```

Remember to revert changes to [`Gemfile.lock`](https://github.com/department-of-veterans-affairs/vets-api/blob/master/Gemfile.lock) before merging any PR's this way!