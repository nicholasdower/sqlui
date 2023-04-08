# frozen_string_literal: true

require_relative '../checks'
require_relative 'file'

module Github
  # A GitHub file tree.
  class Tree
    include Checks
    include Enumerable

    attr_reader :truncated, :files

    def initialize(files:, truncated: false)
      @files = check_enumerable_of(files, File)
      @truncated = check_boolean(truncated: truncated)
    end

    class << self
      include Checks

      def for(owner:, repo:, ref:, tree_response:)
        check_non_empty_string(owner: owner, repo: repo, ref: ref)
        check_is_a(tree_response: [Hash, tree_response])

        truncated = check_boolean(truncated: tree_response['truncated'])
        tree = check_is_a(tree: [Array, tree_response['tree']])
        files = tree.map do |blob|
          File.new(
            owner: owner,
            repo: repo,
            ref: ref,
            tree_sha: tree_response['sha'],
            path: blob['path'],
            content: blob['content']
          )
        end

        Tree.new(files: files, truncated: truncated)
      end
    end

    def [](path)
      @files.find { |f| f.path == path }
    end

    def each(&block)
      @files.each(&block)
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
