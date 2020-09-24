# Warn if a pull request is too big
PR_SIZE = {
  RECOMMENDED_MAXIMUM: 250,
  ABSOLUTE_MAXIMUM:    1000,
}
EXCLUSIONS = ['Gemfile.lock', '.json', 'spec/fixtures/', '.txt', 'spec/support/vcr_cassettes/', 'app/swagger']

# takes form {"some/file.rb"=>{:insertions=>4, :deletions=>1}}
changed_files = git.diff.stats[:files]

excluded_changed_files = changed_files.select { |key| EXCLUSIONS.any? { |exclusion| key.include?(exclusion) } }
filtered_changed_files = changed_files.reject { |key| EXCLUSIONS.any? { |exclusion| key.include?(exclusion) } }
lines_of_code = filtered_changed_files.sum { |_file, changes| (changes[:insertions] + changes[:deletions]) }

if lines_of_code > PR_SIZE[:RECOMMENDED_MAXIMUM]
  file_summary = <<~HTML
    <details><summary>File Summary</summary>

    #### Included Files

    - #{filtered_changed_files.collect { |key, val| "#{key} (+#{val[:insertions]}/-#{val[:deletions]} )" }.join("\n- ")}

    #### Exclusions

    - #{excluded_changed_files.collect { |key, val| "#{key} (+#{val[:insertions]}/-#{val[:deletions]} )" }.join("\n- ")}

    #### 

    _Note: We exclude the following files when considering PR size_

    ```
    #{EXCLUSIONS}

    ```

    </details>
  HTML

  footer = 'Big PRs are difficult to review, often become stale, and cause delays.'

  if lines_of_code > PR_SIZE[:ABSOLUTE_MAXIMUM]
    msg = "This PR changes `#{lines_of_code}` LoC. In order to ensure each PR receives the proper attention it deserves, those exceeding `#{PR_SIZE[:ABSOLUTE_MAXIMUM]}` will not be reviewed, nor will they be allowed to merge. Please break this PR up into smaller ones. If you have reason to believe that this PR should be granted an exception, please see the [Code Review Guidelines FAQ](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/platform/engineering/code_review_guidelines.md#faq).\n"
    fail(msg + file_summary + footer) 
  else
    msg = "This PR changes `#{lines_of_code}` LoC. In order to ensure each PR receives the proper attention it deserves, we recommend not exceeding `#{PR_SIZE[:RECOMMENDED_MAXIMUM]}`. Expect some delays getting reviews.\n"
    warn(msg + file_summary + footer)
  end
end

# Warn when a PR includes a simultaneous DB migration and application code changes
all_touched_files  = git.added_files + git.modified_files + git.deleted_files
db_files  = all_touched_files.select { |filepath| filepath.include? "db/" }
app_files = all_touched_files.select { |filepath| filepath.include? "app/" }

if !db_files.empty? && !app_files.empty?
  msg = <<~HTML
    Modified files in `db/` and `app/` inside the same PR!

    <details><summary>File Summary</summary>

    #### db file(s)

    - #{db_files.collect { |filepath| "#{filepath}" }.join("\n- ")} 

    #### app file(s)

    - #{app_files.collect { |filepath| "#{filepath}" }.join("\n- ")} 

    </details>

    Database migrations do not run automatically with vets-api deployments. Application code must always be backwards compatible with the DB, both before and after migrations have been run. For more info: 

    - [guidance on safe db migrations](https://github.com/ankane/strong_migrations#checks)
    - [`vets-api` deployment process](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/platform/engineering/deployment.md)

  HTML

  # resolves exception... encode': "\xE2" on US-ASCII (Encoding::InvalidByteSequenceError)
  msg.scrub!('_')

  fail(msg)
end
