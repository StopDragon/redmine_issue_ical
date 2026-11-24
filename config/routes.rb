# frozen_string_literal: true

# The .ics extension is required so feed URLs always end in .ics,
# which some calendar apps look for.
get 'issue_ical/my.:format', to: 'issue_ical#index',
    as: 'my_issue_ical', constraints: { format: 'ics' }
get 'projects/:project_id/issue_ical.:format', to: 'issue_ical#index',
    as: 'project_issue_ical', constraints: { format: 'ics' }
