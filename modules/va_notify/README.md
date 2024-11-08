# VaNotify

VANotify enables internal VA teams and systems to integrate and send notifications to Veterans, their families, and the people who support them both inside and outside the VA.

This module will allow for teams inside `vets-api` to easily integrate with VaNotify.

Depending on which business line you fall under, you may need to have a new Service/API key setup for your use case. Reach out in the [#va-notify-public](https://dsva.slack.com/archives/C010R6AUPHT) channel if you have any questions. Service ID, Template ID, and API keys are specific to each env (prod, staging, etc.), so you will need to update the devops repo(s) to properly reference the correct values for each relevant env). https://depo-platform-documentation.scrollhelp.site/developer-docs/settings

There are several options for interacting with the `VaNotify` module

### Using the service class directly (inline/synchronous sending)
Example usage to send an email using the `VaNotify::Service` class (using va.gov's api key and template):

```ruby
notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)

# send email using an email address
notify_client.send_email(
  {
    email_address: 'some_email@example.com',
    template_id: Settings.vanotify.services.va_gov.template_id.some_template_name,
    personalisation: {
      'fname' => 'first_name',
      'date_submitted' => '01/02/2023',
    }
  }
)

# send email using an ICN (utilizing MPI/VA Profile)
notify_client.send_email(
  {
    recipient_identifier: { id_value: 'ICN_VALUE_HERE', id_type: 'ICN' },
    template_id: Settings.vanotify.services.va_gov.template_id.some_template_name,
    personalisation: {
      'fname' => 'first_name',
      'date_submitted' => '01/02/2023',
    }
  }
)
```

Please note the spelling of the `personalisation` param.

### Using the wrapper sidekiq class (async sending)

Example usage to send an email using the `VANotify::EmailJob` (there is also a `VANotify::UserAccountJob` for sending via an ICN, [without persisting or logging the ICN](#misc)).
This class defaults to using the va.gov service's api key but you can provide your own service's api key as show below.

```ruby
    VANotify::EmailJob.perform_async(
      email,
      Settings.vanotify.services.YOUR_SERVICE_NAME_HERE.template_id.YOUR_TEMPLATE_ID_HERE,
      {
        'first_name' => parsed_form.dig('veteranFullName', 'first')&.upcase.presence,
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
        'confirmation_number' => guid
      },
      Settings.vanotify.services.YOUR_SERVICE_NAME_HERE.api_key
    )
```


### API key details

Api keys need to be structured using the following format:
`NAME_OF_API_KEY-YOUR_SERVICE_UUID-API_KEY`

- `NAME_OF_API_KEY` - VANotify's internal name for your api key (will be provided with your API key)
- `YOUR_SERVICE_ID` - The UUID corresponding to your service
- `API_KEY` - Actual API key

Example for a service with the following attributes:
- Name of Api key: `foo-bar-normal-key`
- Service id: `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa`
- Api key: `bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb`

Expected format: `foo-bar-normal-key-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb`

Please reach out via [#va-notify-public](https://dsva.slack.com/archives/C010R6AUPHT) if you have any questions.

#### Misc
ICNs are considered PII and therefore should not be logged or stored. https://depo-platform-documentation.scrollhelp.site/developer-docs/personal-identifiable-information-pii-guidelines#PersonalIdentifiableInformation(PII)guidelines-NotesandpoliciesregardingICNs

# Zero Silent Failures Initiative.
Providing some additional context around using VA Notify in `vets-api` and preventing silent failures for notifications.

## VA Notify Error Classifications.
### API Requests - System Availability, Request Authorization, and Data Validation.

When a client makes an API call to VA Notify, the API first authorizes the request, and then confirms all required fields are present and in the appropriate format. Once this has been validated, the API will return a success code and notification_id, ending the transaction. You should save that notification_id for troubleshooting, and future status updates. From there, the notification proceeds to a delivery workflow.

### Notification Delivery - Contact Lookups and Deliverability.

Our delivery workflow includes retries for errors that may be temporary in nature, like service availability. If your API request includes a recipient_identifier, then VA Notify kicks off our lookup integrations. First, we use MPI to do a deceased check and identify the correlated VA Profile ID. Once we have the VA Profile ID, we use VA Profile to retrieve the email address on file for the Veteran. If there are issues finding the Veteran’s profile or contact information, then VA Notify is unable to deliver the notification. This would indicate that the Veteran needs an alternative communication method or an updated email address. If an email address is successfully retrieved or the API request includes the email address directly, then the notification moves on to delivery via our email provider.

There are a couple of reasons that can cause an email notification to fail such as hard bounces and soft bounces. Hard bounces indicate a permanent failure due to an invalid, unreachable email address. Soft bounces indicate a temporary failure, which could succeed after retry. However, there’s many reasons for soft bounces, some of which require manual effort by the recipient or recipient’s organization if they are utilizing a managed email service (e.g. a work email). Email settings could be blocking these notifications from being delivered. If your notification continues to soft bounce, it’s unlikely to succeed with more send attempts.

## API Requests -  VA system to system communication.

### VA Notify provides a Rails module that exposes two ways of integrating.

1. Service class - eg `VaNotify::Service.new(some_api_key).send_email(some_args)` basic example [here](https://github.com/department-of-veterans-affairs/vets-api/tree/master/modules/va_notify#using-the-service-class-directly-inlinesynchronous-sending).
2. Prebuilt sidekiq jobs eg `VANotify::EmailJob.perform_async(some_args)` basic example [here](https://github.com/department-of-veterans-affairs/vets-api/tree/master/modules/va_notify#using-the-wrapper-sidekiq-class-async-sending).

Using option #1:
- The VA Notify service class operates synchronously and will raise an exception whenever a request to the VA Notify API fails.
	- If you are using the service class to process the user's request inline (like a form submission) the exception will propagate up through the application (unless you have error handling that catches the failure) and cause the entire request to fail (which will then show the user an error message).
	- If you are using the service class within your own sidekiq job a VA Notify error will cause your sidekiq job to retry (unless you have error handling that catches the failure). You will need to have your own error handling in place to handle this scenario.

Using option #2:
- Invoking the sidekiq job via `.perform_async` - because this is an async call it will not fail inline.
- The sidekiq job could fail when it is picked by a sidekiq worker - if the job fails for any reason it will automatically [retry](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/va_notify/app/sidekiq/va_notify/email_job.rb#L7) If the job continues to fail it will eventually go to the dead queue (visible in the [sidekiq dashboard](https://api.va.gov/sidekiq/morgue) and this Datadog [dashboard](https://app.ddog-gov.com/sb/f327ad72-c02a-11ec-a50a-da7ad0900007-260dfe9b82780fef7f07b002e4355281)).

### VA Notify Callback Integration Guide for Vets-API

To effectively track the status of individual notifications, you need to set up service callbacks that VA Notify provides. These callbacks will allow you to determine if each notification you send was successfully delivered, or if it failed. The delivery status callbacks provide real-time feedback, enabling you to monitor the delivery process and handle any issues.

#### Why Teams Need to Integrate with Callback Logic

A successful request to the VA Notify API does not guarantee that the recipient will receive the notification. Callbacks are crucial because they provide updates on the actual delivery status of each notification sent. Without callbacks, teams would be unaware of issues such as email hard bounces, soft bounces, or other delivery problems. Integrating callback logic allows teams to:

- Monitor delivery success rates and identify issues.

- Improve user experience by taking timely corrective actions when notifications fail.

- Maintain compliance and consistency in Veteran communications.

- Ensure that alternative contact methods can be utilized in case of persistent issues.

#### How Teams Can Integrate with Callbacks

To integrate with our callback system, follow these simple steps:

1. Create a Callback Handler Class: Define a class in your module to handle callbacks, which must implement a class-level method `.call`.

Here is an example:
```
module VANotify
  class <name>Callback
    def self.call(notification)
      case notification.status
      when 'delivered'
        StatsD.increment('api.vanotify.notifications.delivered')
      when 'permanent-failure'
        StatsD.increment('api.vanotify.notifications.permanent_failure')
        Rails.logger.error(notification_id: notification.notification_id, source: notification.source_location,
                           status: notification.status, status_reason: notification.status_reason)
      else
        StatsD.increment('api.vanotify.notifications.other')
        Rails.logger.error(notification_id: notification.notification_id, source: notification.source_location,
                           status: notification.status, status_reason: notification.status_reason)
      end
    end
  end
end
```

2. Integrate Callback Logic in Notification Triggers: Behind a feature flag, choose one of your notification triggers and update the way you are invoking VA Notify to pass in your callback data.

Here is an example:
```
VANotify::EmailJob.perform_async(
  email_address,
  template_id,
  template_params,
  Settings.vanotify.services.va_gov.api_key,
  { callback: 'ExampleTeam::NotificationCallbacks', metadata: 'option metadata here'}
)
```

#### Behind the Scenes: How Callbacks Work

1. Here's a high-level overview of what happens behind the scenes when using VA Notify callbacks:

2. Notification Sending: When a notification is sent via the VA Notify API, a notification_id is generated and returned. This ID should be saved to track the delivery status.

3. Delivery Processing: VA Notify attempts to deliver the notification using its internal delivery workflow. This includes retries for temporary issues and contact lookups if an ICN is used.

4. Callback Triggered: As the delivery progresses, VA Notify sends status updates to the configured callback URL. Updates may include statuses like "delivered," "failed," or "temporary failure."

5. Handling Callback: Your application receives the callback and processes it to determine if further action is needed—such as notifying the user of a failed delivery, retrying, or marking the notification as successfully delivered.

#### Contact Us

If you need any further clarification or help during the integration process, feel free to reach out:

- Slack Channel: #va-notify-public
