# frozen_string_literal: true

require_relative '../checks'

module Github
  # Methods for dealing with GitHub paths.
  class Paths
    class << self
      include Checks

      # "<owner>/<repo>/<ref>/<some_path>"
      PATH_PATTERN = %r{^(?:[^/]+/){3}.*[^/]$}
      private_constant :PATH_PATTERN

      # Parses a path like "<owner>/<repo>/<ref>/<some_path>" into owner, repo, ref, path.
      def parse_file_path(path)
        check_non_empty_string(path: path)
        raise "invalid path: #{path}" unless PATH_PATTERN.match?(path)

        owner, repo, ref, *path = path.split('/')
        path = path.join('/')

        [owner, repo, ref, path]
      end
    end
  end
end
