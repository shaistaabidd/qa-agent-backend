require 'rails_helper'

RSpec.describe 'GraphQL: dashboard aggregation queries', type: :request do
  def graphql(query, variables: {}, token: nil)
    headers = { 'CONTENT_TYPE' => 'application/json' }
    headers['Authorization'] = "Bearer #{token}" if token

    post '/graphql', params: { query: query, variables: variables }.to_json, headers: headers
    response.parsed_body
  end

  let!(:admin) { create(:user) }
  let!(:project) { create(:project) }
  let(:admin_token) { Users::GenerateToken.call!(user: admin).token }

  before { create(:membership, user: admin, project: project, role: :admin) }

  describe 'findingsSummary' do
    it 'breaks findings down by severity and ClickUp posting status' do
      run = create(:run, project: project)
      create(:finding, run: run, title: 'A', severity: :high, clickup_task_id: 'task-1')
      create(:finding, run: run, title: 'B', severity: :high, clickup_task_id: nil)
      create(:finding, run: run, title: 'C', severity: :low, clickup_task_id: nil)

      result = graphql(<<~GQL, token: admin_token)
        query {
          findingsSummary(projectId: "#{project.id}") {
            total
            postedToClickUp
            pendingClickUp
            bySeverity { severity count }
          }
        }
      GQL

      summary = result.dig('data', 'findingsSummary')
      expect(summary['total']).to eq(3)
      expect(summary['postedToClickUp']).to eq(1)
      expect(summary['pendingClickUp']).to eq(2)

      counts = summary['bySeverity'].to_h { |row| [row['severity'], row['count']] }
      expect(counts).to include('HIGH' => 2, 'LOW' => 1, 'MEDIUM' => 0, 'CRITICAL' => 0)
    end

    it 'returns zeroed-out data for a project with no findings, rather than erroring' do
      result = graphql(
        "query { findingsSummary(projectId: \"#{project.id}\") { total postedToClickUp } }",
        token: admin_token
      )

      summary = result.dig('data', 'findingsSummary')
      expect(summary['total']).to eq(0)
      expect(summary['postedToClickUp']).to eq(0)
    end

    it 'forbids a non-member with a 403' do
      outsider_token = Users::GenerateToken.call!(user: create(:user)).token

      result = graphql(
        "query { findingsSummary(projectId: \"#{project.id}\") { total } }",
        token: outsider_token
      )

      expect(result.dig('errors', 0, 'code')).to eq(403)
    end
  end

  describe 'coverage' do
    it 'measures tested (has a run) against approved scope features, not all scope features' do
      tested_approved = create(:scope_feature, project: project, name: 'Checkout', approved: true)
      create(:run, project: project, scope_feature: tested_approved)
      create(:scope_feature, project: project, name: 'Refunds', approved: true) # approved, never run
      create(:scope_feature, project: project, name: 'Draft feature', approved: false)

      result = graphql(<<~GQL, token: admin_token)
        query {
          coverage(projectId: "#{project.id}") {
            totalScopeFeatures
            approvedScopeFeatures
            testedScopeFeatures
            coveragePercentage
          }
        }
      GQL

      coverage = result.dig('data', 'coverage')
      expect(coverage['totalScopeFeatures']).to eq(3)
      expect(coverage['approvedScopeFeatures']).to eq(2)
      expect(coverage['testedScopeFeatures']).to eq(1)
      expect(coverage['coveragePercentage']).to eq(50.0)
    end

    it 'returns 0% instead of dividing by zero when nothing is approved yet' do
      result = graphql(
        "query { coverage(projectId: \"#{project.id}\") { coveragePercentage } }",
        token: admin_token
      )

      expect(result.dig('data', 'coverage', 'coveragePercentage')).to eq(0.0)
    end

    it 'counts a scope feature with multiple runs only once toward tested coverage' do
      feature = create(:scope_feature, project: project, approved: true)
      create_list(:run, 3, project: project, scope_feature: feature)

      result = graphql(
        "query { coverage(projectId: \"#{project.id}\") { testedScopeFeatures } }",
        token: admin_token
      )

      expect(result.dig('data', 'coverage', 'testedScopeFeatures')).to eq(1)
    end
  end

  describe 'runsForProject status filter' do
    it 'filters the run queue by status' do
      create(:run, project: project, status: :queued)
      create(:run, project: project, status: :running)
      create(:run, project: project, status: :completed)

      result = graphql(
        "query { runsForProject(projectId: \"#{project.id}\", status: RUNNING) { allData { status } } }",
        token: admin_token
      )

      statuses = result.dig('data', 'runsForProject', 'allData').pluck('status')
      expect(statuses).to eq(['RUNNING'])
    end

    it 'returns every status when no filter is given' do
      create(:run, project: project, status: :queued)
      create(:run, project: project, status: :completed)

      result = graphql(
        "query { runsForProject(projectId: \"#{project.id}\") { allData { status } } }",
        token: admin_token
      )

      expect(result.dig('data', 'runsForProject', 'allData').size).to eq(2)
    end
  end
end
