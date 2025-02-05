# RFC: Faceted Search Technical Specification

## 1. Title

Faceted Search

## 2. Overview

This specification describes the implementation of robust filtering, sorting, and search functionality across multiple data sets (e.g., notifications, secure messages, medical records, claims). The goal is to empower users to quickly narrow down and reorder information using our Rails API and React UI. In addition, drawing from our existing SearchClickTracking service, we will incorporate rigorous parameter sanitization, leverage service objects for external integrations and analytics, and ensure robust monitoring and error handling.

## 3. Scope

- **Filtering:** Allow users to narrow results using multiple attributes (e.g., document type, date ranges). Users must be able to view, modify, and clear active filters.
- **Sorting:** Enable users to reorder a fixed list of information without altering the underlying data. The sort action will utilize a simple, accessible Select/Dropdown component.
- **Search:** Provide full-text search capabilities using PostgreSQL’s built-in features (via pg_search), with the potential to upgrade to a dedicated search engine (e.g., Elasticsearch) if needed.
- **UI Adaptability:** Ensure responsive design that adapts filtering UI for small screens (using accordions or modals) and provides persistent filters on larger screens.
- **Analytics & Monitoring:** Integrate best practices from the SearchClickTracking service for tracking user interactions, including robust parameter sanitization, external service calls via service objects, and comprehensive monitoring.

## 4. Functional Requirements

### 4.1 Backend (Rails)

- **Search Integration:**
  - Utilize the `pg_search` gem for full-text search across multiple models.
  - Index searchable data, including text within documents, to support the search functionality.

- **Filtering and Sorting API:**
  - Accept query parameters such as `filter[type]`, `filter[date_range]`, `sort_by`, and `order`.
  - Implement filtering and sorting via ActiveRecord scopes and dedicated query objects. Examples include:
    - `.by_type`
    - `.by_date_range`
    - `.sorted_by`
  - Enforce parameter whitelisting and sanitize all incoming parameters. Following the pattern in the SearchClickTrackingController, leverage Rails’ `ActionView::Helpers::SanitizeHelper` to ensure data integrity.

- **Pagination:**
  - Use `will_paginate` to paginate results when dealing with large datasets.

- **Authorization & Security:**
  - Apply Pundit (or an equivalent authorization system) to ensure users only access their own data.
  - Validate, permit, and sanitize all filter, sort, and search parameters using strong parameter conventions.

- **Service Object Pattern for External Integrations:**
  - Similar to the SearchClickTracking service, encapsulate external API calls and analytics tracking in dedicated service objects. This pattern will help maintain lean controllers and clear separation of concerns.
  - Include robust error handling and monitoring (e.g., using StatsD or the `Common::Client::Concerns::Monitoring` module) for any external calls.

### 4.2 Frontend (React)

- **UI Components:**
  - **Filter Component:**
    - Render multiple attribute selectors (checkboxes, dropdowns, or date pickers).
    - Display active filters clearly with options to remove individual filters or reset all selections.
    - For lengthy option lists, initially present popular choices with an option to “Show all categories.”
  - **Sort Component:**
    - Render an accessible Select/Dropdown component that allows users to reorder the results.
    - Ensure that sorting does not require navigation to a new page.

- **State Management & URL Syncing:**
  - Manage filter and sort state locally or via a global state solution (e.g., Redux or Context API).
  - Reflect the current filter and sort criteria in the URL as query parameters for bookmarking and sharing purposes.

- **Typeahead & Debouncing:**
  - Implement a predictive typeahead component for search input.
  - Use debouncing to minimize rapid API calls during user input.

- **Accessibility & Responsiveness:**
  - Ensure all components are keyboard navigable and include proper ARIA roles/attributes.
  - Adapt UI behavior on smaller screens by collapsing filters (using accordions) while keeping them visible on larger displays.

## 5. Non-Functional Requirements

- **Performance:**
  - Debounce user inputs to reduce the frequency of API calls.
  - Ensure frequently filtered or sorted columns in PostgreSQL are appropriately indexed.
  - Cache popular queries when feasible.

- **Scalability:**
  - Design API endpoints and queries to accommodate increased data volumes.
  - Employ pagination to manage large datasets efficiently.

- **Security:**
  - Validate and sanitize all incoming parameters using Rails’ strong parameters and the `sanitize` helper.
  - Ensure that only authenticated users can access their associated data.

- **Maintainability:**
  - Isolate filtering, sorting, and search logic in dedicated query objects and service objects.
  - Follow established design system patterns and document components for future reference.

- **Monitoring & Analytics:**
  - Integrate monitoring similar to the SearchClickTracking service (using modules like StatsD and monitoring concerns) for external API calls and internal performance metrics.
  - Log and track analytics for user interactions (e.g., click tracking, filter usage) using dedicated service objects.

- **Accessibility:**
  - Adhere to best practices for ARIA usage.
  - Ensure that filtering and sorting interfaces are fully navigable via keyboard and screen readers.

## 6. Integration and Workflow

1. **User Interaction (Frontend):**
   - Users interact with Filter and Sort components to specify their criteria.
   - State updates in real time and is optionally reflected in the URL for persistence.
   - A predictive typeahead assists users in refining their search terms.

2. **API Request (Backend):**
   - The React frontend sends API requests to the Rails backend, including sanitized filter and sort parameters.
   - Controllers delegate query logic to dedicated objects that apply pg_search for full-text search and ActiveRecord scopes for filtering and sorting.
   - External integrations (e.g., search click tracking, if applicable) are handled via service objects with robust monitoring and error handling.

3. **Response and Rendering:**
   - The API returns structured JSON data, including result sets, pagination metadata, and details of active filters.
   - React components render results, clearly displaying the applied filters and sort order.

4. **Error Handling:**
   - Provide meaningful error messages for invalid or malformed parameters.
   - Implement fallback defaults when parameters are missing or require sanitization.

## 7. Future Considerations

- **Search Engine Upgrade:**
  - Monitor performance and consider migrating to a dedicated search engine (e.g., Elasticsearch) if data volumes or complexity increase.

- **Design System Contribution:**
  - After validation, integrate Filter and Sort components into the design system for reuse across teams.

- **Enhanced Analytics:**
  - Expand on the analytics tracking model used in the SearchClickTracking service to log additional search and filter interactions.
  - Utilize the logged analytics to refine search relevance and improve user experience.

- **Service Object Expansion:**
  - Leverage the service object pattern for additional external integrations or advanced analytics, ensuring robust monitoring and error handling.

## 8. Acceptance Criteria

- **Functional:**
  - Users can apply filters and sort options without unnecessary page navigation.
  - Data is accurately returned based on applied filters, sort orders, and search terms.
  - Typeahead suggestions are responsive and relevant.

- **Non-Functional:**
  - API responses are delivered within acceptable timeframes.
  - The UI remains accessible and responsive across various devices.
  - Security measures ensure that only authenticated users access their data and that all inputs are sanitized.

- **Integration:**
  - Filtering and sorting functionality integrates seamlessly with existing search and data display components.
  - URL query parameters reflect the current state and support bookmarking and sharing.
  - External API calls (if any) follow the service object pattern with robust error handling and monitoring.
