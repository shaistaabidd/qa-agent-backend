module QaProbe
  # Turns concrete SQL into a shape shared by every execution of the same
  # query, so "WHERE id = 7" and "WHERE id = 9" count as one query run twice.
  module Sql
    module_function

    def normalize(sql)
      sql.to_s
         .gsub(%r{/\*.*?\*/}m, "") # query log tags / comments
         .gsub(/'(?:[^']|'')*'/, "?")
         .gsub(/\$\d+/, "?")
         .gsub(/\b\d+(\.\d+)?\b/, "?")
         .gsub(/\bIN\s*\((?:\s*\?\s*,?)+\)/i, "IN (?)")
         .gsub(/\s+/, " ")
         .strip
    end

    # The main table a SELECT reads, used to suggest which association to preload.
    def table(sql)
      sql[/\bFROM\s+"?(\w+)"?/i, 1]
    end
  end
end
