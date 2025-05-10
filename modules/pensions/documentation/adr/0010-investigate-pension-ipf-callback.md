# 10. Investigation of Pension IPF Callbacks

Date: 2024-11-12

## Status

N/A

## Context

Our team is evaluating the callback `pension_ipf_callbacks` in `config/routes.rb`, accompanying flipper 
and `controller app/controllers/v1/pension_ipf_callbacks_controller.rb`. This ADR is to figure out if we still need it or not.

vets-website
`pension_ipf_callbacks_endpoint`: Pension IPF VANotify notification callbacks endpoint

vets-api
```
create_table :pension_ipf_notifications do |t|
   t.text :payload_ciphertext
   t.text :encrypted_kms_key

   t.timestamps
end
```

Looks like there is a script `PensionReminderIpfProcessor` that lives in teams/benefits/scripts/pensions/in-progress-forms.md where it's main job is to "Get all IPF and send reminder email to Veteran" from
`/tmp/ipf-reminder-pension.csv`

Daniel Lim was the last person to modify this script. He mentioned that the script is not used anywhere. 
> It was for a one-time reminder to be sent out to veterans with an old pre-existing application they had started prior to our overhaul, informing them that there was a major overhaul to the online form and they'd essentially need to restart it. The IPF callback endpoint was an attempt to interface with VANotify to capture additional metrics regarding the email blast, i.e. emails sent, received, opened, links clicked, etc. but due to an issue with the authentication bearer token not being recognized, we weren't actually able to use this callback endpoint.


## Decision
After a quick word with Daniel, it seems clear to me that this was used only as an attempt to notify veterans with old applications and should not be needed moving forward.

Things that need removal:
- Migration to remove DB table
- Endpoint in `routes.rb`
- `pension_ipf_callbacks_controller.rb`
- Flipper `:pension_ipf_callbacks_endpoint`
- PensionIpfNotification model 
- `pension_ipf_vanotify_status_callback` in `settings.yml` and `test.yml`
- Rspec file

## Consequences
There doesn't seem to be any consequences with this logic's removal.
