# frozen_string_literal: true

require_relative '../checks'
require_relative 'file'

module Github
  # A GitHub file tree.
  class Tree
    include Checks
    include Enumerable

    attr_reader :owner, :repo, :ref, :truncated, :files

    def initialize(owner:, repo:, ref:, files:, truncated: false)
      @owner = check_non_empty_string(owner:)
      @repo = check_non_empty_string(repo:)
      @ref = check_non_empty_string(ref:)
      @files = check_enumerable_of(files, File)
      @truncated = check_boolean(truncated:)
    end

    class << self
      include Checks

      def for(owner:, repo:, ref:, tree_response:)
        check_non_empty_string(owner:, repo:, ref:)
        check_is_a(tree_response: [Hash, tree_response])

        truncated = check_boolean(truncated: tree_response['truncated'])
        tree = check_is_a(tree: [Array, tree_response['tree']])
        files = tree.map do |blob|
          File.new(
            owner:,
            repo:,
            ref:,
            tree_sha: tree_response['sha'],
            path: blob['path'],
            content: blob['content']
          )
        end

        Tree.new(owner:, repo:, ref:, files:, truncated:)
      end
    end

    def [](path)
      @files.find { |f| f.path == path }
    end

    def each(&)
      @files.each(&)
    end

    def ==(other)
      self.class == other.class &&
        @files == other.files &&
        @truncated == other.truncated
    end

    def <<(file)
      check_is_a(file: [File, file])

      @files << file unless @files.include?(file)
    end
  end
end
