# Additional notes on get_form_hash_686c()

The purpose of this readme is to add some context and information to `app/services/bgs/dependent_v2_service.rb` and specifically to get_form_hash_686c()  The main concern is around the identifiers used in `get_form_hash_686c()`.  As noted in the comments in code, the SSN really shouldn't be included because the SOAP service doesn't use it.

<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:per="http://person.services.vetsnet.vba.va.gov/">
  <soapenv:Header/>
  <soapenv:Body>
   <per:findPersonsByPtcpntIds>
     <!--Zero or more repetitions:-->
     <ptcpntId>?</ptcpntId>
   </per:findPersonsByPtcpntIds>
  </soapenv:Body>
</soapenv:Envelope>

```
def get_form_hash_686c
      begin
        #  The inclusion of ssn as a parameter is necessary for test/development environments, but really isn't needed in production
        #  This will be fixed in an upcoming refactor by @TaiWilkin
        bgs_person = lookup_bgs_person
```
After the check in `lookup_bgs_person` for `bgs_person.present?`, we currently have a second check for lookup by SSN.    A couple versions (one liner vs if/else) of this lookup has been in place for a while, but it seems to serve no purpose.  Even after logging was added to DataDog ([PR here](https://github.com/department-of-veterans-affairs/vets-api/commit/ec5602459650d16dcc509d65dc78c25a76e77662)), there were no instances of the else being hit in the [logs](https://vagov.ddog-gov.com/logs?query=%22BGS%3A%3ADependentService%23get_form_hash_686c%20found%20bgs_person%20by%20ssn%22&agg_m=count&agg_m_source=base&agg_t=count&cols=host%2Cservice&messageDisplay=inline&refresh_mode=sliding&storage=hot&stream_sort=desc&viz=stream&from_ts=1763921404855&to_ts=1765217404855&live=true).

The next line piece of code is used to grab the file number from `bgs_person`

```
        @file_number = bgs_person[:file_nbr]
        # BGS's file number is supposed to be an eight or nine-digit string, and
        # our code is built upon the assumption that this is the case. However,
        # we've seen cases where BGS returns a file number with dashes
        # (e.g. XXX-XX-XXXX). In this case specifically, we can simply strip out
        # the dashes and proceed with form submission.
        @file_number = file_number.delete('-') if file_number =~ /\A\d{3}-\d{2}-\d{4}\z/
```

This piece of code here seems to make assumptions that aren't backed up in conversations with the CorpDB team.  From a conversation with Alex Mikuliak:

> "...only Veterans have a file number – persons can be anyone – spouses, children, etc. but remember; a spouse, child, etc. could be a Veteran also… hence why we abandoned file number as a  key a long time ago in favor of PTCPNT_ID – file number is a TRAIT – and we should avoid using it (like avoiding using SSN) as much as possible."

In the case above where we try to extract `@file_number = bgs_person[:file_nbr]` but the file_number is not the same as the participant ID.  This probably hasn't been a big issue because the primary users of the 686c form are veterans who have a file number.    Back in app/controllers/v0/benefits_claims_controller.rb#31, we do a check to see if file number is present in `check_for_file_number()`, but it seems like we only log it and don't do anything else.

It might seem redundant. but this change seems to better capture the issue in our own code, rather than a shared file.

```ruby
        # Safely extract file number from BGS response as an instance variable for later use;
        # handle malformed bgs_person gracefully
        begin
          @file_number = bgs_person[:file_nbr]
        rescue => e
          @monitor.track_event('warn',
                              'BGS::DependentService#get_form_hash_686c invalid bgs_person file_nbr',
                              "#{STATS_KEY}.file_number.parse_failure",
                              { error: e.message })
          @file_number = nil
        end
```

Lastly, if there is an issue with BGS being down or with a missing file number, we log but allow for it to continue.  This continuation might seem odd, but it is so that the PDF can still be created and then used in the back-up Lighthouse route.

```
      # This rescue could be hit if BGS is down or unreachable when trying to run find_person_by_ptcpnt_id()
      # It could also be hit if the file number is invalid or missing. We log and continue since we can
      # fall back to using Lighthouse and want to still generate the PDF.
      rescue
        @monitor.track_event('warn',
                             'BGS::DependentService#get_form_hash_686c failed',
                             "#{STATS_KEY}.get_form_hash.failure", { error: 'Could not retrieve file number from BGS' })
      end
```





