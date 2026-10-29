module Types
  class FindingSourceEnum < BaseEnum
    description "Where a finding's problem lives"

    value "FRONTEND", "The browser: JS crashes, console errors, blank screens, page speed, leaks", value: "frontend"
    value "BACKEND", "The server: exceptions, SQL and N+1, memory, 5xx, GraphQL errors, slow responses",
          value: "backend"
    value "NETWORK", "A request that was rejected (4xx) or never completed", value: "network"
  end
end
