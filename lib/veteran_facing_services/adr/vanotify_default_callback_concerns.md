# VANotify::DefaultCallback Concerns

_reference modules/va_notify/lib/default_callback.rb_

TL;DR

- Equal investment from teams to use callback_klass vs callback_metadata
- Incorrect recording of silent_failue* metrics
- Potential duplicate recording of silent_failure* metrics
- Runtime errors if missing metadata fields
- Redundant and not extensible
- Lack of documentation

```
VANotify::Notification (
    notification_type: email, # may not always be an email, not all emails are for ZSF
    status: delivered, # handling statuses (not delivered or permament-failure) is not presents
    callback_metadata: { # if not present records incorrect ZSF metric
        notification_type: error, # confounds the field name on Notification
        form_number: 1234, # the name is not consistent with `form_id` used elsewhere
        statsd_tags: { # if not present will cause runtime error
            service: xxxApplication,
            function: xxxFunction
        }
    }
)

VANotify::Notification (
    notification_type: nil # incorrect metric recorded for ZSF email
    status: temporary-failure, # unhandled status
    callback_klass: xxxCallback, # not all callbacks will require metadata, incorrect metrics
    callback_metadata: { foo: bar } # metadata present specific to custom callback => error
)
```

There are new fields on a VANotify::Notification - callback_klass and callback_metadata. Neither callback_klass and/or callback_metadata are required arguments to VANotify notification jobs, ie. VANotify::EmailJob.  Expecting callback_metadata versus callback_klass is still requiring a field to be present.  Teams will need to apply the same resources to adding either or both parameters.

A lack of callback_metadata (a specifically formatted hash) will cause a ‘silent_failure’ metric to be recorded regardless of the notification source or type.  Reporting is triggered solely by the presence, or lack of, callback_metadata.  This will create a large amount of noise in the reporting and will never be fully eliminated - not all notifications will need a callback and others will use a bespoke class and bespoke metadata.  There will be a significant increase in unnecessary effort and time placed in reconciling the false-positive “silent_failure none-provided”.  Decisions will be made based on faulty and misleading data.

A callback_klass can be invoked without any need for callback_metadata - in this case a none-provided silent failure metric is recorded even though there is a callback.  This is in addition to any monitoring taking place in the provided class, which may also be reporting silent failure metrics. Example:

```
Class BespokeErrorCallback
def call(notification)
    case notification.status
    when ‘permanent-failure’
        Rails.logger.error(‘delivery failed’)
    end
end
end
```

Within callback_metadata, if ‘notification_type’ is not provided, no reporting will take place - none-provided or any other.  This is an optional key in an optional field which is responsible for VANotify::DefaultCallback to function.  This is particularly relevant to when a bespoke callback_klass is being provided. If callback_metadata is provided, but the keys do not match what is expected in VANotify::DefaultCallback, runtime errors will occur, specifically:

`undefined method '[]' for nil (NoMethodError)`
```
      notification_type = metadata['notification_type']
      statsd_tags = metadata['statsd_tags']
      service = statsd_tags['service']
      function = statsd_tags['function']
      tags = ["service:#{service}", "function:#{function}"]
```

VANotify::DefaultCallback does not handle any status other than ‘delivered’ and ‘permanent-failure’, omitting, for example, ‘temporary-failure’ and ‘preferences-declined’, or providing a default catch to other statuses.
[VANotify Error Table](https://github.com/department-of-veterans-affairs/vanotify-team/blob/main/Support/error_status_reason_mapping.md#error-table)

VANotify::DefaultCallback is not general purpose and redundant to VANotify::StatusUpdate.

VANotify::DefaultCallback is not extensible by other teams without requiring further modification to the va_notify module.

There is a lack of clear documentation explaining how and why to use VANotify::DefaultCallback, and the results of doing so, or not, ie. the monitoring happening. There is no documentation in the code to inform a developer of the expected arguments or data types.
