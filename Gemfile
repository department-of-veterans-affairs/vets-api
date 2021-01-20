# frozen_string_literal: true

source 'https://rubygems.org'

ruby '2.6.6'

# temp fix for security vulnerability, hopefulle we can remove this line with the next rails patch
# https://blog.jcoglan.com/2020/06/02/redos-vulnerability-in-websocket-extensions/
gem 'websocket-extensions', '>= 0.1.5'

# Modules
path 'modules' do
  gem 'appeals_api'
  gem 'apps_api'
  gem 'claims_api'
  gem 'covid_research'
  gem 'covid_vaccine'
  gem 'health_quest'
  gem 'mobile'
  gem 'openid_auth'
  gem 'va_forms'
  gem 'vaos'
  gem 'vba_documents'
  gem 'veteran'
  gem 'veteran_confirmation'
  gem 'veteran_verification'
end

# Anchored versions, do not change
gem 'puma', '~> 4.3.7'
gem 'puma-plugin-statsd', '~> 0.1.0'
gem 'rails', '~> 6.0.2'

# Gems with special version/repo needs
gem 'active_model_serializers', git: 'https://github.com/department-of-veterans-affairs/active_model_serializers', branch: 'master'
gem 'sidekiq-scheduler', '~> 3.0' # TODO: explanation

gem 'aasm'
gem 'activerecord-import'
gem 'activerecord-postgis-adapter', '~> 6.0.0'
gem 'addressable'
gem 'attr_encrypted', '3.1.0'
gem 'aws-sdk-s3', '~> 1'
gem 'aws-sdk-sns', '~> 1'
gem 'betamocks', git: 'https://github.com/department-of-veterans-affairs/betamocks', branch: 'master'
gem 'bgs_ext', git: 'https://github.com/department-of-veterans-affairs/bgs-ext.git', require: 'bgs'
gem 'breakers'
gem 'carrierwave'
gem 'carrierwave-aws'
gem 'clam_scan'
gem 'combine_pdf'
gem 'config'
gem 'connect_vbms', git: 'https://github.com/department-of-veterans-affairs/connect_vbms.git', branch: 'master', require: 'vbms'
gem 'date_validator'
gem 'dry-struct'
gem 'dry-types'
gem 'faraday'
gem 'faraday_middleware'
gem 'fast_jsonapi'
gem 'fastimage'
gem 'fhir_client', '~> 4.0.4'
gem 'flipper'
gem 'flipper-active_record'
gem 'flipper-active_support_cache_store'
gem 'flipper-ui'
gem 'foreman'
gem 'govdelivery-tms', '2.8.4', require: 'govdelivery/tms/mail/delivery_method'
gem 'gyoku'
gem 'holidays'
gem 'httpclient'
gem 'ice_nine'
gem 'iso_country_codes'
gem 'json', '>= 2.3.0'
gem 'json-schema'
gem 'json_schemer'
gem 'jsonapi-parser'
gem 'jwt'
gem 'levenshtein-ffi'
gem 'liquid'
gem 'mail', '2.7.1'
gem 'memoist'
gem 'mini_magick', '~> 4.10.1'
gem 'net-sftp'
gem 'nokogiri', '~> 1.11'
gem 'notifications-ruby-client', '~> 5.1'
gem 'oj' # Amazon Linux `json` gem causes conflicts, but `multi_json` will prefer `oj` if installed
gem 'olive_branch'
gem 'operating_hours'
gem 'ox'
gem 'paper_trail'
gem 'parallel'
gem 'pdf-forms'
gem 'pdf-reader'
gem 'pg'
gem 'pg_query', '>= 0.9.0'
gem 'pghero'
gem 'prawn'
gem 'prawn-table'
gem 'pundit'
gem 'rack'
gem 'rack-attack'
gem 'rack-cors', require: 'rack/cors'
gem 'rails-session_cookie'
gem 'rails_semantic_logger', '~> 4.4'
gem 'redis'
gem 'redis-namespace'
gem 'request_store'
gem 'restforce'
gem 'rgeo-geojson'
gem 'ruby-saml'
gem 'rubyzip', '>= 1.3.0'
gem 'savon'
gem 'sentry-raven'
gem 'shrine'
gem 'staccato'
gem 'statsd-instrument', '~> 2.6.0' # versions beyond 2.6 deprecate config and change logging messages
gem 'strong_migrations'
gem 'swagger-blocks'
gem 'typhoeus'
gem 'utf8-cleaner'
gem 'vets_json_schema', git: 'https://github.com/department-of-veterans-affairs/vets-json-schema', branch: 'master'
gem 'virtus'
gem 'will_paginate'

group :development do
  gem 'benchmark-ips'
  gem 'guard-rubocop'
  gem 'seedbank'
  gem 'spring', platforms: :ruby # Spring speeds up development by keeping your application running in the background
  gem 'spring-commands-rspec'

  # Include the IANA Time Zone Database on Windows, where Windows doesn't ship with a timezone database.
  # POSIX systems should have this already, so we're not going to bring it in on other platforms
  gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'debase'
  gem 'ruby-debug-ide', git: 'https://github.com/corgibytes/ruby-debug-ide', branch: 'feature-add-fixed-port-range'
  gem 'web-console', platforms: :ruby
end

group :test do
  gem 'apivore', git: 'https://github.com/department-of-veterans-affairs/apivore', branch: 'master'
  gem 'fakeredis'
  gem 'pact', require: false
  gem 'pact-mock_service', require: false
  gem 'pdf-inspector'
  gem 'rspec-retry'
  gem 'rspec_junit_formatter'
  gem 'rubocop-junit-formatter'
  # < 0.18 required due to bug with reporting to CodeClimate
  # https://github.com/codeclimate/test-reporter/issues/418
  gem 'simplecov', '< 0.18', require: false
  gem 'super_diff'
  gem 'vcr'
  gem 'webrick', '>= 1.6.1'
end

# rubocop:disable Metrics/BlockLength
group :development, :test do
  gem 'awesome_print', '~> 1.8' # Pretty print your Ruby objects in full color and with proper indentation
  gem 'bootsnap', require: false
  gem 'brakeman', '~> 4.7'
  gem 'bundler-audit'
  gem 'byebug', platforms: :ruby # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'danger'
  gem 'database_cleaner'
  gem 'factory_bot_rails', '> 5'
  gem 'faker'
  # CAUTION: faraday_curl may not provide all headers used in the actual faraday request. Be cautious if using this to
  # assist with debugging production issues (https://github.com/department-of-veterans-affairs/vets.gov-team/pull/6262)
  gem 'faraday_adapter_socks'
  gem 'faraday_curl'
  gem 'fuubar'
  gem 'guard-rspec', '~> 4.7'
  gem 'overcommit'
  gem 'parallel_tests'
  gem 'pry-byebug'
  gem 'rack-test', require: 'rack/test'
  gem 'rack-vcr'
  gem 'rainbow' # Used to colorize output for rake tasks
  gem 'rspec-instrumentation-matcher'
  gem 'rspec-its'
  gem 'rspec-rails'
  gem 'rubocop', require: false
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'rubocop-thread_safety'
  gem 'sidekiq', '~> 5.0'
  gem 'timecop'
  gem 'webmock'
  gem 'yard'
end
# rubocop:enable Metrics/BlockLength

# sidekiq enterprise requires a license key to download. In many cases, basic sidekiq is enough for local development
if (Bundler::Settings.new(Bundler.app_config_path)['enterprise.contribsys.com'].nil? ||
    Bundler::Settings.new(Bundler.app_config_path)['enterprise.contribsys.com']&.empty?) &&
   ENV.fetch('BUNDLE_ENTERPRISE__CONTRIBSYS__COM', '').empty?
  Bundler.ui.warn 'No credentials found to install Sidekiq Enterprise. This is fine for local development but you may not check in this Gemfile.lock with any Sidekiq gems removed. The README file in this directory contains more information.'
else
  source 'https://enterprise.contribsys.com/' do
    gem 'sidekiq-ent'
    gem 'sidekiq-pro'
  end
end
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
28
29
30
31
32
33
34
35
36
37
38
39
40
41
42
43
44
45
46
47
48
49
50
51
52
53
54
55
56
57
58
59
60
61
62
63
64
65
66
67
68
69
70
71
72
73
74
75
76
77
78
79
80
81
82
83
84
85
86
87
88
89
90
91
92
93
94
95
96
97
98
99
100
101
102
103
104
105
106
107
108
109
110
111
112
113
114
115
116
117
118
119
120
121
122
123
124
125
126
127
128
129
130
131
132
133
134
135
136
137
138
139
140
141
142
143
144
145
146
147
148
149
150
151
152
153
154
155
156
157
158
159
160
161
162
163
164
165
166
167
168
169
170
171
172
173
174
175
176
177
178
179
180
181
182
183
184
185
186
187
188
189
190
191
192
193
194
195
196
197
198
199
200
201
202
203
204
205
206
207
208
209
210
211
212
213
214
215
216
217
218
219
220
221
222
223
224
225
226
227
228
229
230
231
232
233
234
235
236
237
238
239
240
241
242
243
244
245
246
247
248
249
250
251
252
253
254
255
256
257
258
259
260
261
262
263
264
265
266
267
268
269
270
271
272
273
274
275
276
277
278
279
280
281
282
283
284
285
286
287
288
289
290
291
292
293
294
295
296
297
298
299
300
301
302
303
304
305
306
307
308
309
310
311
312
313
314
315
316
317
318
319
320
321
322
323
324
325
326
327
328
329
330
331
332
333
334
335
336
337
338
339
340
341
342
343
344
345
346
347
348
349
350
351
352
353
354
355
356
357
358
359
360
361
362
363
364
365
366
367
368
369
370
371
372
373
374
375
376
377
378
379
380
381
382
383
384
385
386
387
388
389
390
391
392
393
394
395
396
397
398
399
400
401
402
403
404
405
406
407
408
409
410
411
412
413
414
415
416
417
418
419
420
421
422
423
424
425
426
427
428
429
430
431
432
433
434
435
436
437
438
439
440
441
442
443
444
445
446
447
448
449
450
451
452
453
454
455
456
457
458
459
460
461
462
463
464
465
466
467
468
469
470
471
472
473
474
475
476
477
478
479
480
481
482
483
484
485
486
487
488
489
490
491
492
493
494
495
496
497
498
499
500
501
