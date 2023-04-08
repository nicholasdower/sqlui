# frozen_string_literal: true

require_relative '../checks'

module Github
  # A GitHub file.
  class File
    include Checks

    attr_reader :full_path, :path, :tree_sha, :content, :github_url

    def initialize(owner:, repo:, ref:, tree_sha:, path:, content:)
      check_non_empty_string(owner: owner, repo: repo, ref: ref, path: path, tree_sha: tree_sha)
      @full_path = "#{owner}/#{repo}/#{ref}/#{path}"
      @path = path
      @tree_sha = tree_sha
      @content = check_is_a(content: [String, content])
      @github_url = "https://github.com/#{owner}/#{repo}/blob/#{ref}/#{path}"
    end

    def ==(other)
      self.class == other.class &&
        @full_path == other.full_path &&
        @path == other.path &&
        @tree_sha == other.tree_sha &&
        @content == other.content &&
        @github_url == other.github_url
    end
  end
end
