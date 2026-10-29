module Projects
  # "Tested" means an approved scope feature has at least one run, passing or not. Coverage is
  # measured against approved features only, since unapproved ones aren't in scope yet.
  class Coverage
    def initialize(project)
      @project = project
    end

    def call
      approved = @project.scope_features.where(approved: true)
      approved_count = approved.count
      tested_count = approved.joins(:runs).distinct.count

      {
        total_scope_features: @project.scope_features.count,
        approved_scope_features: approved_count,
        tested_scope_features: tested_count,
        coverage_percentage: percentage(tested_count, approved_count)
      }
    end

    private

    def percentage(numerator, denominator)
      return 0.0 unless denominator.positive?

      (numerator.to_f / denominator * 100).round(1)
    end
  end
end
