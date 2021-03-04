# Appeals API


## Executive Summary
The current appeals process is manual, cumbersome, and is backlogged by ~400,000 claims due to the time it takes to submit, receive, review, and process appeals claims. By adding an API to support automation of this process, we believe we will be able to reduce the time it takes to submit and review claims, as well as the number of claims in the backlog. This will be a significant internal benefit, however, we also believe we can further improve the process by allowing VSOs to integrate with our API to support appeal claims and make Veteran lives easier. Allowing VSOs to manage Decision Reviews online will save them time, allowing them to spend their time serving more Veterans instead of faxing or mailing forms to the VA.

## User Problem Statements
    - I am a Veteran or dependent who has received an unfavorable decision on my original claim. For various reasons (time, money, lack of complexity) I would like to file a decision review request myself, but there is no way to do that online. Moreover, the paper forms I have to fill out don't make sense, and ask me for information that the VA already knows. If I make a mistake on these forms it could set my case back years!

    - I am a VA.gov engineer building a UI for submitting a Higher Level Review benefit appeal. I need a simple endpoint to send the data I gather on the UI for the Higher Level Review Decision Review request to the VA so the request can be processed.

    - I work at a VSO and spend my time helping Veterans through the complex benefit appeal process. I spend a lot of time helping veterans fill out paper forms, then faxing them to the VA. This process is frustrating as it is time consuming and not always easy to know when the documents have been received by the VA.

## Audiences Served

- Veterans (end product)

- VA.gov engineers (Integrate with API)

- Commercial API Consumers (Integrate with API)

- VSOs (utilize tools integrated with API)

- Appeal Intake Processors (less forms to process manually)

- Central Mail (less forms to process manually)

- VSRs (lower rate of errors in data)

## Overview

There are three different Appeal types.

- Supplemental Claim

- Higher-level Review

- Board Appeal (Notice of Disagreement)

## Metrics

- Number of decision reviews submitted via Decision Review API

- Decrease number of Decision Reviews submitted via mail and fax

- Time spent by a Veteran or VSO Officer to submit a decision review request to VA

- Reduction in time from submission of the Decision Review to decision communicated to the Veteran

## Data flow

Currently - this project receives form data from a single consumer `va.gov`,
with the plans to open the API for general VA consumption.

- Form data for one of the requisite Appeal types is received (Currently only
    Higher-level review is supported.)
- Form data validated against schema, data requirements
- PDF form is generated and uploaded to Central Mail
